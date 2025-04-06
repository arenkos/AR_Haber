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
    // ... (Properties: news, isLoading, hasMoreContent, cancellables, currentPage) ...

    // --- Helper Functions (downloadImage, getDocumentsDirectory, deleteAllSavedNews) remain the same ---
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func downloadImage(from url: URL, completion: @escaping (String?) -> Void) {
        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            print("Image already exists: \(destinationURL.path)")
            completion(destinationURL.path)
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let location = location, error == nil else {
                print("Error downloading image \(url.absoluteString): \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: location, to: destinationURL)

                if UIImage(contentsOfFile: destinationURL.path) != nil {
                     print("Image successfully saved: \(destinationURL.path)")
                } else {
                     print("Image file saved but couldn't be loaded at: \(destinationURL.path)")
                }

                completion(destinationURL.path)
            } catch {
                 if let nsError = error as NSError?, nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteFileExistsError {
                     print("Image file likely already moved (fileExistsError): \(destinationURL.path)")
                     completion(destinationURL.path)
                 } else {
                     print("Error saving image to \(destinationURL.path): \(error)")
                     completion(nil)
                 }
            }
        }
        task.resume()
    }

     func deleteAllSavedNews() {
         let fileManager = FileManager.default
         let documentsDirectory = getDocumentsDirectory()
         
         do {
             let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
             let deletableExtensions = ["png", "jpg", "jpeg", "gif", "webp", "webarchive", "pdf", ""]
             
             for fileURL in fileURLs {
                 if deletableExtensions.contains(fileURL.pathExtension.lowercased()) {
                     try fileManager.removeItem(at: fileURL)
                      print("Deleted: \(fileURL.lastPathComponent)")
                 }
             }
             print("All cached news images/files deleted.")
         } catch {
             print("Error deleting cached files: \(error)")
         }
     }

    // --- Modified Loading Functions ---

    func loadNews(resetPage: Bool = false, arama: String, isSearch: Bool = false) {
        // ... (guard conditions, reset logic, URL setup remain the same) ...
        guard !isLoading else { return }
        guard hasMoreContent || resetPage else {
             print("LoadNews: Already loading or no more content and not resetting.")
             return
         }

        if resetPage {
            currentPage = 0
            news.removeAll()
            hasMoreContent = true
        }

        isLoading = true

        var components = URLComponents(string: "https://www.aryazilimdanismanlik.com/armedya/haberler_mobil.php")
        components?.queryItems = [
            URLQueryItem(name: "arama", value: arama),
            URLQueryItem(name: "carpan", value: String(currentPage))
        ]

        guard let url = components?.url else {
            print("Invalid URL components.")
            isLoading = false
            return
        }

        print("Loading News URL: \(url.absoluteString)")

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [NewsItem].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    print("Error fetching news: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] fetchedNewsItems in
                guard let self = self else { return }

                if fetchedNewsItems.isEmpty {
                    self.hasMoreContent = false
                    print("No more news items received.")
                    return
                }

                let startIndex = self.news.count
                self.news.append(contentsOf: fetchedNewsItems)
                self.currentPage += 1

                // --- Download Images Logic ---
                for i in startIndex..<self.news.count {
                    let item = self.news[i]
                    // Directly use item.resim_url since it's not optional
                    let originalUrlString = item.resim_url

                    // Still need to validate if the string forms a proper URL
                    guard let imageUrl = URL(string: originalUrlString) else {
                        print("Item \(item.id) has invalid image URL string: \(originalUrlString)")
                        continue // Skip if the string is not a valid URL format
                    }

                    // Avoid re-downloading if it's already a local path (heuristic check)
                    if !originalUrlString.starts(with: "http") && originalUrlString.contains("/") {
                         print("Item \(item.id) already appears to have a local path: \(originalUrlString)")
                         continue
                    }

                    // Start download - ADD [weak self] to capture list
                    self.downloadImage(from: imageUrl) { [weak self] localPath in
                        // Ensure update happens on the main thread
                        DispatchQueue.main.async {
                            // Correctly unwrap self and path
                            guard let self = self, let path = localPath else { return }

                            // Find the item again using its Int ID
                            if let indexToUpdate = self.news.firstIndex(where: { $0.id == item.id }) {
                                // Update the resim_url property
                                self.news[indexToUpdate].resim_url = path
                                // print("Updated image path for item \(item.id) to: \(path)")
                            } else {
                                 print("Could not find item \(item.id) to update path after download.")
                            }
                        }
                    } // End downloadImage closure
                } // End loop
                // --- End Image Download ---
            })
            .store(in: &cancellables)
    }

    func loadfilteredNews(resetPage: Bool = false, arama: String, kaynak: String, kategori: String, isSearch: Bool = false) {
        // ... (guard conditions, reset logic, URL setup remain the same) ...
        guard !isLoading else { return }
        guard hasMoreContent || resetPage else {
             print("loadfilteredNews: Already loading or no more content and not resetting.")
             return
         }

        if resetPage {
            currentPage = 0
            news.removeAll()
            hasMoreContent = true
        }

        isLoading = true

        var components = URLComponents(string: "https://www.aryazilimdanismanlik.com/armedya/haberler_mobil.php")
        components?.queryItems = [
            URLQueryItem(name: "arama", value: arama),
            URLQueryItem(name: "carpan", value: String(currentPage)),
            URLQueryItem(name: "kaynak", value: kaynak),
            URLQueryItem(name: "kategori", value: kategori)
        ]

        guard let url = components?.url else {
            print("Invalid URL components for filtered news.")
            isLoading = false
            return
        }

        print("Loading Filtered News URL: \(url.absoluteString)")

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [NewsItem].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    print("Error fetching filtered news: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] fetchedNewsItems in
                guard let self = self else { return }

                if fetchedNewsItems.isEmpty {
                    self.hasMoreContent = false
                    print("No more filtered news items received.")
                    return
                }

                let startIndex = self.news.count
                self.news.append(contentsOf: fetchedNewsItems)
                self.currentPage += 1

                // --- Download Images Logic (Identical modification as in loadNews) ---
                for i in startIndex..<self.news.count {
                    let item = self.news[i]
                    let originalUrlString = item.resim_url // Use directly

                    guard let imageUrl = URL(string: originalUrlString) else {
                        print("Item \(item.id) has invalid image URL string: \(originalUrlString)")
                        continue
                    }
                    if !originalUrlString.starts(with: "http") && originalUrlString.contains("/") {
                        print("Item \(item.id) already appears to have a local path: \(originalUrlString)")
                        continue
                    }

                    // ADD [weak self] to capture list
                    self.downloadImage(from: imageUrl) { [weak self] localPath in
                         DispatchQueue.main.async {
                             guard let self = self, let path = localPath else { return }
                             if let indexToUpdate = self.news.firstIndex(where: { $0.id == item.id }) {
                                 self.news[indexToUpdate].resim_url = path
                             } else {
                                 print("Could not find item \(item.id) to update path after download.")
                             }
                         }
                     } // End downloadImage closure
                 } // End loop
                // --- End Image Download ---
            })
            .store(in: &cancellables)
    }

    func loadlikedNews(resetPage: Bool = false, arama: String, isSearch: Bool = false, username: String) {
        // ... (guard conditions, reset logic, URL setup remain the same) ...
        guard !isLoading else { return }
        guard hasMoreContent || resetPage else {
            print("loadlikedNews: Already loading or no more content and not resetting.")
            return
        }

        if resetPage {
            currentPage = 0
            news.removeAll()
            hasMoreContent = true
        }

        isLoading = true

        var components = URLComponents(string: "https://www.aryazilimdanismanlik.com/armedya/begenilen_haberler_mobil.php")
        components?.queryItems = [
            URLQueryItem(name: "arama", value: arama),
            URLQueryItem(name: "carpan", value: String(currentPage)),
            URLQueryItem(name: "user", value: username)
        ]

        guard let url = components?.url else {
            print("Invalid URL components for liked news.")
            isLoading = false
            return
        }

        print("Loading Liked News URL: \(url.absoluteString)")

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [NewsItem].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case let .failure(error) = completion {
                    print("Error fetching liked news: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] fetchedNewsItems in
                guard let self = self else { return }

                if fetchedNewsItems.isEmpty {
                    self.hasMoreContent = false
                    print("No more liked news items received.")
                    return
                }

                let startIndex = self.news.count
                self.news.append(contentsOf: fetchedNewsItems)
                self.currentPage += 1

                // --- Download Images Logic (Identical modification as in loadNews) ---
                 for i in startIndex..<self.news.count {
                     let item = self.news[i]
                     let originalUrlString = item.resim_url // Use directly

                     guard let imageUrl = URL(string: originalUrlString) else {
                         print("Item \(item.id) has invalid image URL string: \(originalUrlString)")
                         continue
                     }
                    if !originalUrlString.starts(with: "http") && originalUrlString.contains("/") {
                        print("Item \(item.id) already appears to have a local path: \(originalUrlString)")
                        continue
                    }

                     // ADD [weak self] to capture list
                     self.downloadImage(from: imageUrl) { [weak self] localPath in
                         DispatchQueue.main.async {
                             guard let self = self, let path = localPath else { return }
                             if let indexToUpdate = self.news.firstIndex(where: { $0.id == item.id }) {
                                 self.news[indexToUpdate].resim_url = path
                             } else {
                                 print("Could not find item \(item.id) to update path after download.")
                             }
                         }
                     } // End downloadImage closure
                 } // End loop
                // --- End Image Download ---
            })
            .store(in: &cancellables)
    }

    // Make sure the get() function is completely removed if it exists elsewhere in the file.
}

class NewsViewModel_eski: ObservableObject {
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
            if let uiImage = UIImage(contentsOfFile: news.resim_url) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture(count: 1, perform: onTapGesture)
            } else {
                
                AsyncImage(url: URL(string: news.resim_url)) { image in
                    image.resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture(count: 1, perform: onTapGesture)
                } placeholder: {
                    ProgressView()
                    Text("Resim Yükleniyor...")
                }
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
            //deleteAllSavedNews()
            //get(resim_url: news.resim_url, haber_url: news.haber_url)
            //print("resim:" + resim)
        }
        .padding()
        .sheet(isPresented: $isChatListViewPresented) {
            if let user = authViewModel.user {
                ChatListView(senderId: user.username, newsItem: news) // Burada haber bilgilerini geçiyoruz
            }
        }
    }
    func get(resim_url: String, haber_url: String) {
        let webView = WKWebView()
        guard let url = URL(string: haber_url), let imageURL = URL(string: resim_url) else { return }
        
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
                                print(resim)
                            }
                        }
                        
                    } catch {
                        print("WebArchive kaydedilirken hata oluştu: \(error)")
                    }
                }
            }
        }
    }
    func deleteAllSavedNews() {
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsDirectory()
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            // .webarchive ve resim dosyalarını sil
            for fileURL in fileURLs {
                if fileURL.pathExtension == "" || fileURL.pathExtension == "webarchive" || fileURL.pathExtension == "pdf" || fileURL.pathExtension == "jpg" || fileURL.pathExtension == "png" || fileURL.pathExtension == "jpeg" {
                    try fileManager.removeItem(at: fileURL)
                }
            }
            
            print("Tüm indirilen haberler ve resimler silindi.")
        } catch {
            print("Haberleri silerken hata oluştu: \(error)")
        }
    }
    
    func downloadImage(from url: URL, completion: @escaping (String?) -> Void) {
        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
        
        // **Dosya zaten varsa direkt olarak path döndür**
        if fileManager.fileExists(atPath: destinationURL.path) {
            print(url)
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
