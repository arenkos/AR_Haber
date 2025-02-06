import SwiftUI
import WebKit
import Combine
import GoogleMobileAds

struct NewsItem: Identifiable, Codable, Hashable {
    var id: Int
    var baslik: String
    var tarih: String
    var kaynak: String
    var resim_url: String
    var haber_url: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case baslik
        case tarih
        case kaynak
        case resim_url
        case haber_url
    }
}

class NewsViewModel: ObservableObject {
    @Published var news: [NewsItem] = []
    @Published var isLoading = false
    @Published var hasMoreContent = true
    
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 0
    
    func loadNews(resetPage: Bool = false, arama: String, isSearch: Bool = false) {
        guard hasMoreContent && !isLoading else { return }
        
        if resetPage {
            currentPage = 0
            news.removeAll()
            hasMoreContent = true
        }
        
        if isSearch && resetPage {
            currentPage = 0
            hasMoreContent = true
        }
        
        isLoading = true
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/haberler_mobil.php?arama=\(arama)&carpan=\(currentPage)"
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else {
            print("Invalid URL: \(urlString)")
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [NewsItem].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    print("Error fetching data: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] newsItems in
                guard let self = self else { return }
                
                if newsItems.isEmpty {
                    self.hasMoreContent = false
                    return
                }
                
                self.news.append(contentsOf: newsItems)
                self.currentPage += 1
            })
            .store(in: &cancellables)
    }
}

// AdConstants'ı güncelleyelim
struct AdConstants {
    static let appID = "ca-app-pub-6912090056166853~3231299076"
    
    // Test reklamları için
    static let testBannerID = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialID = "ca-app-pub-3940256099942544/4411468910"
    
    // Gerçek reklamlar için
    static let bannerAdUnitID = "ca-app-pub-6912090056166853/1918217405"
    static let interstitialAdUnitID = "ca-app-pub-6912090056166853/1918217405"
    
    static let requestDelay: TimeInterval = 10.0
    
    // Kullanılacak reklam kimliklerini seç
    static var currentBannerID: String {
        #if DEBUG
        return bannerAdUnitID
        #else
        return bannerAdUnitID
        #endif
    }
    
    static var currentInterstitialID: String {
        #if DEBUG
        return interstitialAdUnitID
        #else
        return interstitialAdUnitID
        #endif
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            // Ana Sayfa Sekmesi
            Genel_Akis()
                .tabItem {
                    Label("Genel Akış", systemImage: "house.fill")
                }
            /*
            // Haberler Sekmesi
            Kaynak()
                .tabItem {
                    Label("Kaynak", systemImage: "newspaper.fill")
                }
            
            // Kategori Sekmesi
            Kategori()
                .tabItem {
                    Label("Kategori", systemImage: "square.grid.2x2.fill") // İkon güncellendi
                }
            
            // Özel Akış Sekmesi
            Ozel_Akis()
                .tabItem {
                    Label("Özel Akış", systemImage: "star.fill") // İkon güncellendi
                }*/
        }
        .accentColor(.blue)
    }
}

struct NewsItemView: View {
    let news: NewsItem
    let mapSource: (String) -> String
    let onTapGesture: () -> Void
    /*let onDoubleTapGesture: () -> Void
    let isLiked: Bool
    let isDisliked: Bool
    let onLike: () -> Void
    let onDislike: () -> Void
    let onComment: () -> Void*/
    
    var body: some View {
                            VStack(alignment: .center) {
                                // Kaynak Logosunu Gösterme
                                HStack {
                let kaynak = mapSource(news.kaynak)
                                    AsyncImage(url: URL(string: "https://www.aryazilimdanismanlik.com/armedya/logo/" + kaynak + ".png")) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 50, height: 50)
                                    .padding(.trailing, 8)
                                }
                                
            // Haber Görseli
                                AsyncImage(url: URL(string: news.resim_url)) { image in
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture(count: 1, perform: onTapGesture)
                    /*.onTapGesture(count: 2, perform: onDoubleTapGesture)*/
                                } placeholder: {
                                    ProgressView()
                                }
                                
                                // Başlık ve Tarih
                                Text(news.baslik)
                                    .font(.headline)
                                    .padding(.vertical, 8)
                .onTapGesture(perform: onTapGesture)
                                
                                Text(news.tarih)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                // Like, Dislike ve Yorum Butonları
                                HStack {
                /*Button(action: onLike) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .gray)
                }
                
                Button(action: onDislike) {
                    Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(isDisliked ? .red : .gray)
                }
                
                Button(action: onComment) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.gray)
                }*/
            }
            .padding(.top, 5)
        }
        .padding()
    }
}

// AdBannerView'ı güncelleyelim
struct AdBannerView: UIViewRepresentable {
    let adUnitID = AdConstants.currentBannerID
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let screenWidth = UIScreen.main.bounds.width // Ekran genişliğini al
        containerView.frame = CGRect(origin: .zero, size: CGSize(width: screenWidth, height: 200)) // Ekran genişliğini kullan
        
        let bannerView = BannerView()
        bannerView.adSize = AdSizeBanner
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }
        
        containerView.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Kenarlarda boşluk bırakmak için 20 birim boşluk ekleyelim
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            bannerView.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: -40), // 20 birim sağdan ve soldan boşluk
            bannerView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // Reklam yükle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let request = Request()
            bannerView.load(request)
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("Banner reklam yüklendi")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner reklam yüklenemedi: \(error.localizedDescription)")
        }
    }
}

// NewsListView'ı güncelleyelim
struct NewsListView: View {
    let news: [NewsItem]
    let mapSource: (String) -> String
    let isLoading: Bool
    let onNewsSelected: (NewsItem) -> Void
    /*let onReaction: (Int, Bool) -> Void
    let isLiked: (Int) -> Bool
    let isDisliked: (Int) -> Bool
    let onComment: () -> Void*/
    let onLoadMore: () -> Void
    
    var body: some View {
        LazyVStack {
            ForEach(Array(news.enumerated()), id: \.element.id) { index, newsItem in
                VStack {
                    /*NewsItemView(
                        news: newsItem,
                        mapSource: mapSource,
                        onTapGesture: { onNewsSelected(newsItem) },
                        onDoubleTapGesture: { onReaction(newsItem.id, true) },
                        isLiked: isLiked(newsItem.id),
                        isDisliked: isDisliked(newsItem.id),
                        onLike: { onReaction(newsItem.id, true) },
                        onDislike: { onReaction(newsItem.id, false) },
                        onComment: onComment
                    )*/
                    NewsItemView(
                        news: newsItem,
                        mapSource: mapSource,
                        onTapGesture: { onNewsSelected(newsItem) }
                    )
                    .onAppear {
                        if index == news.count - 3 {
                            onLoadMore()
                        }
                    }
                    
                    if (index + 1) % 4 == 0 {
                        Text("-Sponsorlu Bağlantı-")
                            .frame(maxWidth: .infinity, alignment: .center)
                        AdBannerView()
                            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200) // Genişlik esnek, yükseklik sabit
                            .padding(.horizontal, 10) // Sağdan ve soldan 10 birim boşluk bırak
                    }
                }
            }
            
            if isLoading {
                ProgressView()
                    .padding()
            }
        }
    }
}

struct Genel_Akis: View {
    @StateObject private var viewModel = NewsViewModel()
    @State private var selectedNews: NewsItem?
    @State private var showCommentsView = false
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var showWebView = false
    @State private var likedNewsIDs: Set<Int> = []
    @State private var dislikedNewsIDs: Set<Int> = []
    @State private var arama = ""
    @State private var interstitial: InterstitialAd?
    
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
        if arama.isEmpty {
            return viewModel.news
        } else {
            return viewModel.news.filter { $0.baslik.localizedCaseInsensitiveContains(arama) }
        }
    }
    
    var body: some View {
        VStack {
            
            SearchBar(text: $arama)
                .onChange(of: arama) { oldValue, newValue in
                    viewModel.loadNews(resetPage: true, arama: arama, isSearch: true)
                }
            
            ScrollView {
                /*NewsListView(
                    news: arama.isEmpty ? viewModel.news : filteredNews,
                    mapSource: mapSource,
                    isLoading: viewModel.isLoading,
                    onNewsSelected: { news in
                                    selectedNews = news
                                    showWebView = true
                    },
                    onReaction: toggleReaction,
                    isLiked: isLiked,
                    isDisliked: isDisliked,
                    onComment: { showCommentsView.toggle() },
                    onLoadMore: {
                        if !viewModel.isLoading {
                            viewModel.loadNews(resetPage: false, arama: arama)
                        }
                    }
                )*/
                NewsListView(
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
                )
            }
            .onAppear {
                if viewModel.news.isEmpty {
                    viewModel.loadNews(arama: "")
                }
            }
            .refreshable {
                viewModel.news.removeAll()
                viewModel.loadNews(resetPage: true, arama: "")
            }
            .sheet(isPresented: $showCommentsView) {
                if let selectedNews = selectedNews {
                    WebViewContainer(urlString: "https://www.aryazilimdanismanlik.com/armedya/yorumlar.php?id=\(selectedNews.id)") {
                        showCommentsView = false
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-100) // Tam ekran genişlik
                }
            }
            .sheet(isPresented: $showWebView) {
                if let selectedNews = selectedNews {
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
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/tepki_mobil.php?begenme=\(begenme)&begen=\(begen)&id=\(newsID)") else { return }
        
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

    func isLiked(newsID: Int) -> Bool {
        return likedNewsIDs.contains(newsID)
    }

    func isDisliked(newsID: Int) -> Bool {
        return dislikedNewsIDs.contains(newsID)
    }
    func skip(){
        
    }
}

struct Ozel_Akis: View {
    @StateObject private var viewModel = NewsViewModel()
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
        if arama.isEmpty {
            return viewModel.news
        } else {
            return viewModel.news.filter { $0.baslik.localizedCaseInsensitiveContains(arama) }
        }
    }
    
    var body: some View {
        VStack {
            
            SearchBar(text: $arama)
                .onChange(of: arama) { oldValue, newValue in
                    viewModel.loadNews(resetPage: true, arama: arama, isSearch: true)
                }
            
            ScrollView {
                /*NewsListView(
                    news: arama.isEmpty ? viewModel.news : filteredNews,
                    mapSource: mapSource,
                    isLoading: viewModel.isLoading,
                    onNewsSelected: { news in
                                    selectedNews = news
                                    showWebView = true
                    },
                    onReaction: toggleReaction,
                    isLiked: isLiked,
                    isDisliked: isDisliked,
                    onComment: { showCommentsView.toggle() },
                    onLoadMore: {
                        if !viewModel.isLoading {
                            viewModel.loadNews(resetPage: false, arama: arama)
                        }
                    }
                )*/
                NewsListView(
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
                )
            }
            .onAppear {
                if viewModel.news.isEmpty {
                    viewModel.loadNews(arama: "")
                }
            }
            .refreshable {
                viewModel.news.removeAll()
                viewModel.loadNews(resetPage: true, arama: "")
            }
            .sheet(isPresented: $showCommentsView) {
                if let selectedNews = selectedNews {
                    WebViewContainer(urlString: "https://www.aryazilimdanismanlik.com/armedya/yorumlar.php?id=\(selectedNews.id)") {
                        showCommentsView = false
                    }
                }
            }
            .sheet(isPresented: $showWebView) {
                if let selectedNews = selectedNews {
                    WebViewContainer(urlString: "https://www.aryazilimdanismanlik.com/armedya/tiklanma.php?haber_url=" + String(selectedNews.haber_url)) {
                        showWebView = false
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // Tam ekran genişlik
                    .hidden()
                    
                    WebViewContainer(urlString: selectedNews.haber_url) {
                        showWebView = false
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // Tam ekran genişlik
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
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/tepki_mobil.php?begenme=\(begenme)&begen=\(begen)&id=\(newsID)") else { return }
        
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

    func isLiked(newsID: Int) -> Bool {
        return likedNewsIDs.contains(newsID)
    }

    func isDisliked(newsID: Int) -> Bool {
        return dislikedNewsIDs.contains(newsID)
    }
}

struct Kategori: View {
    @State private var categories: [String] = [] // To hold fetched categories
    @State private var isLoading = true // To show loading state
    @State private var tappedCategories: Set<String> = [] // To keep track of tapped categories
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading categories...") // Loading indicator
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                List(categories, id: \.self) { category in
                    HStack {
                        Text(category)
                        
                        Spacer()
                        
                        Button(action: {
                            toggleBell(for: category)
                        }) {
                            Image(systemName: tappedCategories.contains(category) ? "bell.fill" : "bell")
                                .foregroundColor(tappedCategories.contains(category) ? .yellow : .gray)
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchCategories()
        }
    }
    
    // Function to fetch categories
    func fetchCategories() {
        // Assuming user information is availableh dynamic user data
        
        // URL to your PHP script that fetches categories
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/fetch_kategori.php"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Prepare the body for the POST request
        let bodyString = ""
        
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Perform the network request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                self.isLoading = false // Hide loading indicator after request completes
            }
            
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                // Parse the JSON response
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let categories = jsonResponse["kategori"] as? [String] {
                    DispatchQueue.main.async {
                        self.categories = categories // Update the UI with fetched categories
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
    
    // Function to handle bell tap and make the network request
    func toggleBell(for category: String) {
        if tappedCategories.contains(category) {
            tappedCategories.remove(category)
        } else {
            tappedCategories.insert(category)
            
            // Send the request to the PHP script when the bell is tapped
            let urlString = "https://www.aryazilimdanismanlik.com/armedya/arama_kategori.php?kategori=\(category)"
            
            guard let url = URL(string: urlString) else {
                print("Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                guard let _ = data else {
                    print("No data received")
                    return
                }
                
                // Handle response if needed
                print("Request successful for category: \(category)")
            }
            
            task.resume()
        }
    }
}

struct Kaynak: View {
    @State private var categories: [String] = [] // To hold fetched categories
    @State private var isLoading = true // To show loading state
    @State private var tappedCategories: Set<String> = [] // To keep track of tapped categories
    func mapSource(category: String) -> String {
        switch category {
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
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading categories...") // Loading indicator
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                List(categories, id: \.self) { category in
                    HStack {
                        AsyncImage(url: URL(string: "https://www.aryazilimdanismanlik.com/armedya/logo/" + mapSource(category: category) + ".png")) { image in
                            image.resizable().scaledToFit()
                                .frame(height:20)
                        } placeholder: {
                            ProgressView()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            toggleBell(for: category)
                        }) {
                            Image(systemName: tappedCategories.contains(category) ? "bell.fill" : "bell")
                                .foregroundColor(tappedCategories.contains(category) ? .yellow : .gray)
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchCategories()
        }
    }
    
    // Function to fetch categories
    func fetchCategories() {
        // Assuming user information is available
        // let user = "yourUserID" // You can replace this with dynamic user data
        
        // URL to your PHP script that fetches categories
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/fetch_kaynak.php"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Prepare the body for the POST request
        let bodyString = ""
        
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Perform the network request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                self.isLoading = false // Hide loading indicator after request completes
            }
            
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                // Parse the JSON response
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let categories = jsonResponse["kaynak"] as? [String] {
                    DispatchQueue.main.async {
                        self.categories = categories // Update the UI with fetched categories
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
    
    // Function to handle bell tap and make the network request
    func toggleBell(for category: String) {
        if tappedCategories.contains(category) {
            tappedCategories.remove(category)
        } else {
            tappedCategories.insert(category)
            
            // Send the request to the PHP script when the bell is tapped
            let urlString = "https://www.aryazilimdanismanlik.com/armedya/arama_kaynak.php?kaynak=\(category)"
            
            guard let url = URL(string: urlString) else {
                print("Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                guard let _ = data else {
                    print("No data received")
                    return
                }
                
                // Handle response if needed
                print("Request successful for category: \(category)")
            }
            
            task.resume()
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let urlString: String
    let onClose: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            uiView.load(URLRequest(url: url))
        }
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }
    
    class Coordinator: NSObject {
        let onClose: () -> Void
        
        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Search", text: $text)
            .padding(7)
            .padding(.horizontal, 20)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                    Spacer()
                }
            )
            .padding(.horizontal)
    }
}

// GADBannerViewController'ı güncelleyelim
struct GADBannerViewController: UIViewControllerRepresentable {
    let adUnitID = AdConstants.currentBannerID
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.frame = CGRect(origin: .zero, size: CGSize(width: 320, height: 50))
        
        let bannerView = BannerView()
        bannerView.adSize = AdSizeBanner
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = viewController
        bannerView.delegate = context.coordinator
        
        viewController.view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: 320),
            bannerView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Reklam yüklemeyi geciktir
        DispatchQueue.main.asyncAfter(deadline: .now() + AdConstants.requestDelay) {
            let request = Request()
            bannerView.load(request)
        }
        
        return viewController
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("Banner reklam yüklendi")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner reklam yüklenemedi: \(error.localizedDescription)")
        }
    }
}
