//
//  Ozel_Akis.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//  Updated: 2026-01-25 - Fixed API endpoint for filtered news
//

import Combine
import GoogleMobileAds
import SwiftUI
import WebKit

struct Ozel_Akis: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = NewsViewModel()
    @StateObject private var selectedNewsManager = SelectedNewsManager()
    @State private var selectedNews: NewsItem?
    @State private var showCommentsView = false
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var showWebView = false
    @State private var likedNewsIDs: Set<Int> = []
    @State private var dislikedNewsIDs: Set<Int> = []
    @State private var arama = ""
    @State private var kullanici_adi = ""
    @State private var kullanici_sifre = ""
    @State private var interstitial: InterstitialAd?
    @State var tappedSources: Set<String> = []  // To keep track of tapped kaynak
    @State var tappedCategories: Set<String> = []  // To keep track of tapped kategori
    @State private var hasLoadedOnce = false  // Sadece ilk kez yüklensin

    init() {
        loadInterstitial()
    }

    func loadInterstitial() {
        let request = Request()
        InterstitialAd.load(
            with: AdConstants.currentInterstitialID,
            request: request
        ) { [self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
            }
            interstitial = ad
        }
    }

    // Kaynak Logo Eşlemesi
    func mapSource(kaynak: String) -> String {
        switch kaynak {
        case "A HABER": return "ahaber"
        case "CNN TÜRK": return "cnn"
        case "CUMHURİYET": return "cumhuriyet"
        case "HABERTÜRK": return "haberturk"
        case "MİLLİYET": return "milliyet"
        case "NTV": return "ntv"
        case "SABAH": return "sabah"
        case "SHIFTDELETE.NET": return "sdn"
        case "SÖZCÜ": return "sozcu"
        case "TRT HABER": return "trt"
        case "WEBTEKNO": return "webtekno"
        default: return "default_logo"
        }
    }

    // Filtered news based on search text
    var filteredNews: [NewsItem] {
        let selectedSources = tappedSources  // Seçilen kaynakları al
        let selectedCategories = tappedCategories

        // Kaynak ve kategoriye göre filtreleme
        let filteredBySourceAndCategory = viewModel.news.filter {
            selectedSources.contains($0.kaynak) && selectedCategories.contains($0.kategori)
        }

        // Arama yapılıyorsa başlığa göre de filtrele
        if arama.isEmpty {
            return filteredBySourceAndCategory
        } else {
            return filteredBySourceAndCategory.filter {
                $0.baslik.localizedCaseInsensitiveContains(arama)
            }
        }
    }

    var body: some View {
        VStack {

            SearchBar(text: $arama)
                .onChange(of: arama) { oldValue, newValue in
                    viewModel.loadfilteredNews(
                        resetPage: true, arama: arama, kaynak: tappedSources.joined(separator: ","),
                        kategori: tappedCategories.joined(separator: ","))
                    loadUserReactions()
                }

            ScrollView {
                NewsListView(
                    news: arama.isEmpty ? viewModel.news : filteredNews,
                    mapSource: mapSource,
                    isLoading: viewModel.isLoading,
                    onNewsSelected: { news in
                        selectedNewsManager.selectedNews = news
                        showWebView = false
                        DispatchQueue.main.async {
                            showWebView = true
                        }
                    },
                    onReaction: toggleReaction,
                    isLiked: { newsID in
                        likedNewsIDs.contains(newsID)  // Kullanıcının beğendiği haberlerin kontrolü
                    },
                    isDisliked: { newsID in
                        dislikedNewsIDs.contains(newsID)  // Kullanıcının beğenmediği haberlerin kontrolü
                    },
                    onComment: { news in
                        selectedNewsManager.selectedNews = news
                        showCommentsView.toggle()
                    },
                    onLoadMore: {
                        if !viewModel.isLoading {
                            loadUserReactions()
                            viewModel.loadfilteredNews(
                                resetPage: false, arama: arama,
                                kaynak: tappedSources.joined(separator: ","),
                                kategori: tappedCategories.joined(separator: ","))

                        }
                    }
                )
            }
            .onAppear {
                loadUserReactions {
                    //print(dislikedNewsIDs)
                    //print(likedNewsIDs)
                }

                // Her seferinde güncel kaynak ve kategorileri yükle
                let previousSources = tappedSources
                let previousCategories = tappedCategories

                loadTappedSources {
                    loadTappedCategories {
                        // Eğer kaynak veya kategoriler değiştiyse ya da ilk yüklemeyse haberleri yenile
                        if !hasLoadedOnce || previousSources != tappedSources || previousCategories != tappedCategories {
                            viewModel.news.removeAll()
                            viewModel.loadfilteredNews(
                                resetPage: true, arama: "",
                                kaynak: tappedSources.joined(separator: ","),
                                kategori: tappedCategories.joined(separator: ","))
                            print(
                                "Loading filtered news with sources: \(tappedSources.joined(separator: ","))"
                            )
                            print(
                                "Loading filtered news with categories: \(tappedCategories.joined(separator: ","))"
                            )
                            hasLoadedOnce = true
                        }
                    }
                }
            }
            .refreshable {
                // Güncel kaynak ve kategorileri yükle, sonra haberleri yenile
                loadTappedSources {
                    loadTappedCategories {
                        viewModel.news.removeAll()
                        viewModel.loadfilteredNews(
                            resetPage: true, arama: "",
                            kaynak: tappedSources.joined(separator: ","),
                            kategori: tappedCategories.joined(separator: ","))
                    }
                }
                loadUserReactions {
                    //print(dislikedNewsIDs)
                    //print(likedNewsIDs)
                }
            }
            .sheet(isPresented: $showCommentsView) {
                if let selectedNews = selectedNewsManager.selectedNews,
                    let user = authViewModel.user
                {
                    WebViewContainer(
                        urlString:
                            "https://armedia.live/yorumlar.php?id=\(selectedNews.id)&username=\(user.username)"
                    ) {
                        showCommentsView = false
                    }
                    .frame(
                        width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 100
                    )
                }
            }
            .sheet(isPresented: $showWebView) {
                if let selectedNews = selectedNewsManager.selectedNews {
                    // Tıklanma kaydı - ID kullanarak
                    WebViewContainer(
                        urlString:
                            "https://armedia.live/tiklanma.php?id=\(selectedNews.id)"
                    ) {
                        showWebView = false
                    }
                    .frame(width: 0, height: 0)
                    .hidden()

                    // Haber URL'ini akıllıca seç
                    let newsURL: String = {
                        // Eğer haber_url geçerliyse onu kullan
                        if !selectedNews.haber_url.isEmpty
                            && selectedNews.haber_url.starts(with: "http")
                        {
                            return selectedNews.haber_url
                        }
                        // Aksi takdirde ID bazlı endpoint kullan
                        return
                            "https://armedia.live/haber.php?id=\(selectedNews.id)"
                    }()

                    WebViewContainer(urlString: newsURL) {
                        showWebView = false
                    }
                    .frame(
                        width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 100
                    )
                }
            }
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let root = scene.windows.first?.rootViewController
            {
                interstitial?.present(from: root)
                loadInterstitial()
            }
        }
    }

    func loadUserReactions(completion: @escaping () -> Void = {}) {
        guard let user = authViewModel.user else { return }

        let urlString =
            "https://armedia.live/load_user_reactions.php?user=\(user.username)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let jsonResponse =
                    try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                if let jsonResponse = jsonResponse {
                    // Gelen veriyi doğru şekilde parse et
                    let likedIDs = (jsonResponse["liked"] as? [Int]) ?? []
                    let dislikedIDs = (jsonResponse["disliked"] as? [Int]) ?? []

                    DispatchQueue.main.async {
                        self.likedNewsIDs = Set(likedIDs)
                        self.dislikedNewsIDs = Set(dislikedIDs)
                        completion()
                    }
                } else {
                    print("Parsing error: Expected 'liked' and 'disliked' arrays")
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
        }

        task.resume()
    }

    func loadTappedSources(completion: @escaping () -> Void) {
        guard let user = authViewModel.user else {
            print("loadTappedSources: User not logged in")
            completion()  // Kullanıcı yoksa bile completion çağır
            return
        }

        let urlString =
            "https://armedia.live/load_tapped_sources.php?user=\(user.username)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion()
            return
        }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                DispatchQueue.main.async { completion() }
                return
            }

            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async { completion() }
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any],
                    let kaynak = jsonResponse["kaynak"] as? [String]
                {
                    DispatchQueue.main.async {
                        self.tappedSources = Set(kaynak)
                        print("Loaded tapped sources: \(self.tappedSources)")
                        completion()
                    }
                } else {
                    print("Parsing error: Could not load tapped sources")
                    DispatchQueue.main.async { completion() }
                }
            } catch {
                print("JSON parsing error: \(error)")
                DispatchQueue.main.async { completion() }
            }
        }

        task.resume()
    }

    func loadTappedCategories(completion: @escaping () -> Void) {
        guard let user = authViewModel.user else {
            print("loadTappedCategories: User not logged in")
            completion()  // Kullanıcı yoksa bile completion çağır
            return
        }

        let urlString =
            "https://armedia.live/load_tapped_categories.php?user=\(user.username)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion()
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                DispatchQueue.main.async { completion() }
                return
            }

            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async { completion() }
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any],
                    let categories = jsonResponse["categories"] as? [String]
                {
                    DispatchQueue.main.async {
                        self.tappedCategories = Set(categories)
                        print("Loaded tapped categories: \(self.tappedCategories)")
                        completion()
                    }
                } else {
                    print("Parsing error: Could not load tapped categories")
                    DispatchQueue.main.async { completion() }
                }
            } catch {
                print("JSON parsing error: \(error)")
                DispatchQueue.main.async { completion() }
            }
        }

        task.resume()
    }

    func toggleReaction(for newsID: Int, isLike: Bool) {
        if isLike {
            if likedNewsIDs.contains(newsID) {
                likedNewsIDs.remove(newsID)
                isLiked = false
                sendReactionRequest(newsID: newsID, begen: 0, begenme: 0)
            } else {
                likedNewsIDs.insert(newsID)
                isLiked = true
                if dislikedNewsIDs.contains(newsID) {
                    dislikedNewsIDs.remove(newsID)
                }
                sendReactionRequest(newsID: newsID, begen: 1, begenme: 0)
            }
        } else {
            if dislikedNewsIDs.contains(newsID) {
                dislikedNewsIDs.remove(newsID)
                isDisliked = false
                sendReactionRequest(newsID: newsID, begen: 0, begenme: 0)
            } else {
                dislikedNewsIDs.insert(newsID)
                isDisliked = true
                if likedNewsIDs.contains(newsID) {
                    likedNewsIDs.remove(newsID)
                }
                sendReactionRequest(newsID: newsID, begen: 0, begenme: 1)
            }
        }
    }

    func sendReactionRequest(newsID: Int, begen: Int, begenme: Int) {
        if let user = authViewModel.user {
            guard
                let url = URL(
                    string:
                        "https://armedia.live/tepki_mobil.php?begenme=\(begenme)&begen=\(begen)&id=\(newsID)&user=\(user.username)"
                )
            else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("API Request Error: \(error)")
                    return
                }
            }
            task.resume()
        }
    }

    func isLiked(newsID: Int) -> Bool {
        return likedNewsIDs.contains(newsID)
    }

    func isDisliked(newsID: Int) -> Bool {
        return dislikedNewsIDs.contains(newsID)
    }
}
