//
//  SelectedNewsManager.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//

import SwiftUI
import WebKit
import Combine
import GoogleMobileAds


class SelectedNewsManager: ObservableObject {
    @Published var selectedNews: NewsItem?
}

struct NewsItem: Identifiable, Codable, Hashable {
    var id: Int
    var baslik: String
    var tarih: String
    var kaynak: String
    var kategori: String
    var resim_url: String
    var haber_url: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case baslik
        case tarih
        case kaynak
        case kategori
        case resim_url
        case haber_url
    }
}

class NewsViewModel: ObservableObject {
    @EnvironmentObject var authViewModel: AuthViewModel
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
    
    func loadfilteredNews(resetPage: Bool = false, arama: String, kaynak: String, kategori: String, isSearch: Bool = false) {
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
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/haberler_mobil.php?arama=\(arama)&carpan=\(currentPage)&kaynak=\(kaynak)&kategori=\(kategori)"
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
    
    func loadlikedNews(resetPage: Bool = false, arama: String, isSearch: Bool = false, username: String) {
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
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/begenilen_haberler_mobil.php?arama=\(arama)&carpan=\(currentPage)&user=\(username)"
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

// NewsListView'ı güncelleyelim
struct NewsListView: View {
    let news: [NewsItem]
    let mapSource: (String) -> String
    let isLoading: Bool
    let onNewsSelected: (NewsItem) -> Void
    let onReaction: (Int, Bool) -> Void
    let isLiked: (Int) -> Bool
    let isDisliked: (Int) -> Bool
    let onComment: (NewsItem) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        LazyVStack {
            ForEach(Array(news.enumerated()), id: \.element.id) { index, newsItem in
                VStack {
                    NewsItemView(
                        news: newsItem,
                        mapSource: mapSource,
                        onTapGesture: { onNewsSelected(newsItem) },
                        onDoubleTapGesture: { onReaction(newsItem.id, true) },
                        isLiked: isLiked(newsItem.id),
                        isDisliked: isDisliked(newsItem.id),
                        onLike: { onReaction(newsItem.id, true) },
                        onDislike: { onReaction(newsItem.id, false) },
                        onComment: { _ in onComment(newsItem) }
                    )
                    /*NewsItemView(
                        news: newsItem,
                        mapSource: mapSource,
                        onTapGesture: { onNewsSelected(newsItem) }
                    )*/
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

struct NewsItemView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var offlineNewsManager = OfflineNewsManager.shared
    @State private var isChatListViewPresented = false
    let news: NewsItem
    let mapSource: (String) -> String
    let onTapGesture: () -> Void
    let onDoubleTapGesture: () -> Void
    let isLiked: Bool
    let isDisliked: Bool
    let onLike: () -> Void
    let onDislike: () -> Void
    let onComment: (NewsItem) -> Void
    @State var resim = ""
    
    var body: some View {
        VStack(alignment: .center) {
            // Kaynak Logosunu Gösterme
            HStack {
                let kaynak = mapSource(news.kaynak)
                Image(kaynak)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .padding(.trailing, 8)
                /*
                AsyncImage(url: URL(string: "https://www.aryazilimdanismanlik.com/armedya/logo/" + kaynak + ".png?v=\(Date().timeIntervalSince1970)")) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 50, height: 50)
                .padding(.trailing, 8)*/
            }
                
            // Haber Görseli
            if let uiImage = UIImage(contentsOfFile: resim) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture(count: 1, perform: onTapGesture)
            } else {
                Text("Resim Yükleniyor...")
                /*
                AsyncImage(url: URL(string: news.resim_url)) { image in
                    image.resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture(count: 1, perform: onTapGesture)
                } placeholder: {
                    ProgressView()
                }*/
            }
                                
            // Başlık ve Tarih
            Text(news.baslik)
                .font(.headline)
                .padding(.vertical, 8)
                .onTapGesture(perform: onTapGesture)
                                
            Text(news.tarih)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if authViewModel.isLoggedIn {
                // Like, Dislike ve Yorum Butonları
                HStack {
                    Button(action: onLike) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                    }
                    
                    Button(action: onDislike) {
                        Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .foregroundColor(isDisliked ? .red : .gray)
                    }
                    
                    Button(action: { onComment(news) }) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.gray)
                    }
                    
                    // Mesaj Gönder Butonu
                    Button(action: {
                        showChatListView(url: news.haber_url)
                    }) {
                        Image(systemName: "envelope.fill") // Mesaj ikonu
                            .foregroundColor(.gray)
                    }
                    
                    // 🔗 Paylaş Butonu
                    if let url = URL(string: news.haber_url) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up") // Paylaşım ikonu
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Haberi Kaydet Butonu
                    Button(action: {
                        offlineNewsManager.get(kaynak: news.kaynak, haber_url: news.haber_url, resim_url: news.resim_url, baslik: news.baslik, tarih: news.tarih)
                    }) {
                        Image(systemName: "bookmark")  // Kaydetme işlemi için uygun simge
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 5)
            }
        }
        .onAppear {
            get()
            print(resim)
        }
        .padding()
        .sheet(isPresented: $isChatListViewPresented) {
            if let user = authViewModel.user {
                ChatListView(senderId: user.username, newsItem: news) // Burada haber bilgilerini geçiyoruz
            }
        }
    }
    func get() {
        let webView = WKWebView()
        guard let url = URL(string: news.haber_url), let imageURL = URL(string: news.resim_url) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        DispatchQueue.main.asyncAfter(deadline: .now()) { // 5 saniye bekleyerek tam yüklenmesini sağlıyoruz
            webView.takeSnapshot(with: nil) { image, error in
                if let image = image {
                    let fileURL = self.getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).webarchive")
                    
                    do {
                        try image.pngData()?.write(to: fileURL)
                        //print("Sayfa başarıyla kaydedildi: \(fileURL)")
                        
                        // Resmi indir ve kaydet
                        self.downloadImage(from: imageURL) { savedImagePath in
                            if let savedImagePath = savedImagePath {
                                self.resim = savedImagePath
                            }
                        }
                        
                    } catch {
                        print("WebArchive kaydedilirken hata oluştu: \(error)")
                    }
                }
            }
        }
    }
    
    func downloadImage(from url: URL, completion: @escaping (String?) -> Void) {
        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
        
        // **Dosya zaten varsa direkt olarak path döndür**
        if fileManager.fileExists(atPath: destinationURL.path) {
            print("Dosya zaten var: \(destinationURL.path)")
            completion(destinationURL.path)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let location = location, error == nil else {
                print("Resim indirilirken hata oluştu: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                completion(nil)
                return
            }
            
            do {
                try fileManager.moveItem(at: location, to: destinationURL)
                
                // Kaydedilen resmin varlığını kontrol et
                if UIImage(contentsOfFile: destinationURL.path) != nil {
                    print("Resim başarıyla kaydedildi: \(destinationURL.path)")
                } else {
                    print("Resim yüklenemedi.")
                }
                
                completion(destinationURL.path) // Kaydedilen dosyanın yolunu döndür
            } catch {
                print("Resim kaydedilirken hata oluştu: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // Mesaj gönderme arayüzünü açacak fonksiyon
    func showChatListView(url: String) {
        isChatListViewPresented = true
    }
}
