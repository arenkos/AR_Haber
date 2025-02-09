//
//  Ozel.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//

import SwiftUI
import WebKit
import Combine
import GoogleMobileAds


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
    @State var tappedSources: Set<String> = [] // To keep track of tapped kaynak
    @State var tappedCategories: Set<String> = [] // To keep track of tapped kategori
    
    init() {
        loadInterstitial()
    }
    
    func loadInterstitial() {
        let request = Request()
        InterstitialAd.load(with: AdConstants.currentInterstitialID,
                          request: request) { [self] ad, error in
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
        let selectedSources = tappedSources // Seçilen kaynakları al
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
                    viewModel.loadfilteredNews(resetPage: true, arama: arama, kaynak: tappedSources.joined(separator: ","), kategori: tappedCategories.joined(separator: ","))
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
                        likedNewsIDs.contains(newsID) // Kullanıcının beğendiği haberlerin kontrolü
                    },
                    isDisliked: { newsID in
                        dislikedNewsIDs.contains(newsID) // Kullanıcının beğenmediği haberlerin kontrolü
                    },
                    onComment: { showCommentsView.toggle() },
                    onLoadMore: {
                        if !viewModel.isLoading {
                            loadUserReactions()
                            viewModel.loadfilteredNews(resetPage: true, arama: arama, kaynak: tappedSources.joined(separator: ","), kategori: tappedCategories.joined(separator: ","))

                        }
                    }
                )
                /*NewsListView(
                    news: arama.isEmpty ? viewModel.news : filteredNews,
                    mapSource: mapSource,
                    isLoading: viewModel.isLoading,
                    onNewsSelected: { news in
                                    selectedNews = news
                                    showWebView = true
                    },
                    onLoadMore: {
                        if !viewModel.isLoading {
                            viewModel.loadNews(resetPage: false, arama: arama)
                        }
                    }
                )*/
            }
            .onAppear {
                loadUserReactions(){
                    print(dislikedNewsIDs)
                    print(likedNewsIDs)
                }
                loadTappedSources(){
                    loadTappedCategories(){
                        if viewModel.news.isEmpty || !viewModel.news.isEmpty{
                            viewModel.loadfilteredNews(resetPage: true, arama: "", kaynak: tappedSources.joined(separator: ","), kategori: tappedCategories.joined(separator: ","))
                            print(tappedSources.joined(separator: ","))
                            print(tappedCategories.joined(separator: ","))
                        }
                    }
                }
            }
            .refreshable {
                viewModel.news.removeAll()
                viewModel.loadfilteredNews(resetPage: true, arama: "", kaynak: tappedSources.joined(separator: ","), kategori: tappedCategories.joined(separator: ","))
                loadUserReactions(){
                    print(dislikedNewsIDs)
                    print(likedNewsIDs)
                }
            }
            .sheet(isPresented: $showCommentsView) {
                if let selectedNews = selectedNewsManager.selectedNews,
                   let user = authViewModel.user {
                    WebViewContainer(urlString: "https://www.aryazilimdanismanlik.com/armedya/yorumlar.php?id=\(selectedNews.id)&username=\(user.username)") {
                        showCommentsView = false
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-100) // Tam ekran genişlik
                }
            }
            .sheet(isPresented: $showWebView) {
                if let selectedNews = selectedNewsManager.selectedNews {
                    WebViewContainer(urlString: "https://www.aryazilimdanismanlik.com/armedya/tiklanma.php?haber_url=" + String(selectedNews.haber_url)) {
                        showWebView = false
                    }
                    .frame(width: 0, height: 0) // Tam ekran genişlik
                    .hidden()
                    
                    WebViewContainer(urlString: selectedNews.haber_url) {
                        showWebView = false
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-100) // Tam ekran genişlik
                }
            }
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                interstitial?.present(from: root)
                loadInterstitial()
            }
        }
    }
    func loadUserReactions(completion: @escaping () -> Void = {}) {
        guard let user = authViewModel.user else { return }
        print("Kullanıcı ad:" + user.username)
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/load_user_reactions.php?user=\(user.username)"
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
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("JSON Response:", jsonResponse ?? "Invalid JSON") // Gelen JSON'u kontrol et
                
                if let jsonResponse = jsonResponse {
                    // Gelen veriyi doğru şekilde parse et
                    let likedIDs = (jsonResponse["liked"] as? [Int]) ?? []
                    let dislikedIDs = (jsonResponse["disliked"] as? [Int]) ?? []
                    
                    DispatchQueue.main.async {
                        self.likedNewsIDs = Set(likedIDs)
                        self.dislikedNewsIDs = Set(dislikedIDs)
                        print("Liked News:", self.likedNewsIDs)
                        print("Disliked News:", self.dislikedNewsIDs)
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
        guard let user = authViewModel.user else { return }
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/load_tapped_sources.php?user=\(user.username)"
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
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let kaynak = jsonResponse["kaynak"] as? [String] {
                    DispatchQueue.main.async {
                        self.tappedSources = Set(kaynak)
                        completion() // Call completion after data is loaded
                    }
                } else {
                    print("Parsing error")
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
        }
        
        task.resume()
    }

    func loadTappedCategories(completion: @escaping () -> Void) {
        guard let user = authViewModel.user else { return }
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/load_tapped_categories.php?user=\(user.username)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let categories = jsonResponse["categories"] as? [String] {
                    DispatchQueue.main.async {
                        self.tappedCategories = Set(categories)
                        completion() // Call completion after data is loaded
                    }
                } else {
                    print("Parsing error")
                }
            } catch {
                print("JSON parsing error: \(error)")
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

        print("Reaction toggled: \(isLike ? "Liked" : "Disliked")")
    }
    
    func sendReactionRequest(newsID: Int, begen: Int, begenme: Int) {
        if let user = authViewModel.user{
            guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/tepki_mobil.php?begenme=\(begenme)&begen=\(begen)&id=\(newsID)&user=\(user.username)") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("API Request Error: \(error)")
                    return
                }
                print("Response: \(String(describing: response))")
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
