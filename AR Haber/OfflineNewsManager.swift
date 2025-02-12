//
//  OfflineNewsManager.swift
//  AR Haber
//
//  Created by Aren Koş on 12.02.2025.
//


import SwiftUI
import WebKit
import PDFKit

class OfflineNewsManager: ObservableObject {
    static let shared = OfflineNewsManager()
    @Published var offlineNewsList: [OfflineNews] = []  // @Published ekleniyor

    func saveNews(_ news: OfflineNews) {
        offlineNewsList.insert(news, at: 0)  // Yeni haberi listenin başına ekliyoruz
        print(offlineNewsList)
        saveNewsToFile()  // Listeyi kaydediyoruz
    }

    func saveNewsToFile() {
        // Haberleri dosyaya kaydetmek için fonksiyon
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(offlineNewsList) {
            let fileURL = getDocumentsDirectory().appendingPathComponent("offlineNews.json")
            try? data.write(to: fileURL)
        }
    }
    
    
    func downloadAndSaveNewsPage(urlString: String, fileName: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                self.saveHTMLFile(data: data, fileName: fileName)
            }
        }.resume()
    }
    
    func saveHTMLFile(data: Data, fileName: String) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("\(fileName).html")
        
        do {
            try data.write(to: fileURL)
            print("Haber sayfası kaydedildi: \(fileURL)")
        } catch {
            print("HTML kaydedilirken hata oluştu: \(error)")
        }
    }
    
    func getSavedNewsFilePath(fileName: String) -> URL? {
        let fileURL = getDocumentsDirectory().appendingPathComponent("\(fileName).html")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func saveWebArchive(haber_url: String, resim_url: String, baslik: String, tarih: String) {
        let webView = WKWebView()
        guard let url = URL(string: haber_url), let imageURL = URL(string: resim_url) else { return }
        print("save basıldı")
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // 5 saniye bekleyerek tam yüklenmesini sağlıyoruz
            webView.takeSnapshot(with: nil) { image, error in
                if let image = image {
                    let fileURL = self.getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).webarchive")
                    
                    do {
                        try image.pngData()?.write(to: fileURL)
                        print("Sayfa başarıyla kaydedildi: \(fileURL)")
                        
                        // Resmi indir ve kaydet
                        self.downloadImage(from: imageURL) { savedImagePath in
                            if let savedImagePath = savedImagePath {
                                let offlineNews = OfflineNews(kaynak: "Kaynak Adı", resim_url: savedImagePath, baslik: baslik, tarih: tarih, haber_url: fileURL.path)
                                self.saveNews(offlineNews)
                            }
                        }
                        
                    } catch {
                        print("WebArchive kaydedilirken hata oluştu: \(error)")
                    }
                }
            }
        }
    }

    // Resim indirme fonksiyonu
    func downloadImage(from url: URL, completion: @escaping (String?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let location = location, error == nil else {
                print("Resim indirilirken hata oluştu: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                completion(nil)
                return
            }
            
            let fileManager = FileManager.default
            let destinationURL = self.getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
            
            do {
                try fileManager.moveItem(at: location, to: destinationURL)
                
                // Resmi başarıyla kaydettiğimizde, burada resmin var olup olmadığını kontrol ediyoruz
                if let image = UIImage(contentsOfFile: destinationURL.path) {
                    // Görsel başarılı şekilde yüklendi
                    print("Resim başarıyla yüklendi: \(destinationURL.path)")
                } else {
                    print("Resim yüklenemedi.")
                }
                
                completion(destinationURL.path) // Resmin kaydedildiği yolu döndürüyoruz
            } catch {
                print("Resim kaydedilirken hata oluştu: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    func loadSavedNews() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("offlineNews.json")
        
        // 📌 Eğer dosya yoksa, hata almamak için boş bir dizi kaydediyoruz
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("⚠️ Haber dosyası bulunamadı, yeni bir dosya oluşturuluyor...")
            do {
                let emptyArray: [OfflineNews] = []
                let data = try JSONEncoder().encode(emptyArray)
                try data.write(to: fileURL)
                print("✅ Yeni boş haber dosyası oluşturuldu.")
            } catch {
                print("❌ Haber dosyası oluşturulamadı: \(error)")
            }
            return // Dosya zaten oluşturuldu, geri dön
        }

        do {
            let data = try Data(contentsOf: fileURL)
            offlineNewsList = try JSONDecoder().decode([OfflineNews].self, from: data)
            print("✅ Haberler başarıyla yüklendi.")
        } catch {
            print("❌ Haber dosyaları yüklenirken hata oluştu: \(error)")
        }
    }
    
    func deleteAllSavedNews() {
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsDirectory()
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            // .webarchive ve resim dosyalarını sil
            for fileURL in fileURLs {
                if fileURL.pathExtension == "webarchive" || fileURL.pathExtension == "pdf" || fileURL.pathExtension == "jpg" || fileURL.pathExtension == "png" || fileURL.pathExtension == "jpeg" {
                    try fileManager.removeItem(at: fileURL)
                }
            }
            
            // JSON dosyasını sil
            let jsonFile = documentsDirectory.appendingPathComponent("offlineNews.json")
            if fileManager.fileExists(atPath: jsonFile.path) {
                try fileManager.removeItem(at: jsonFile)
            }
            
            // UI güncellemek için listeyi temizle
            DispatchQueue.main.async {
                self.offlineNewsList.removeAll()
            }
            
            print("Tüm indirilen haberler ve resimler silindi.")
        } catch {
            print("Haberleri silerken hata oluştu: \(error)")
        }
    }
    
    func saveNewsAsPDF(urlString: String, fileName: String) {
        let webView = WKWebView()
        guard let url = URL(string: urlString) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // Sayfanın yüklenmesini bekliyoruz
            let pdfFilePath = self.getDocumentsDirectory().appendingPathComponent("\(fileName).pdf")
            
            webView.createPDF { result in
                switch result {
                case .success(let pdfData):
                    do {
                        try pdfData.write(to: pdfFilePath)
                        print("PDF başarıyla kaydedildi: \(pdfFilePath)")
                    } catch {
                        print("PDF kaydedilirken hata oluştu: \(error)")
                    }
                case .failure(let error):
                    print("PDF oluşturulamadı: \(error)")
                }
            }
        }
    }
    
    func saveWebPageAsPDF(haber_url: String, resim_url: String, baslik: String, tarih: String) {
        let webView = WKWebView()
        guard let url = URL(string: haber_url), let imageURL = URL(string: resim_url) else { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("✅ Web sayfası yüklendi, PDF kaydediliyor...")
            
            let pdfFilePath = self.getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).pdf")
            
            webView.createPDF { result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: pdfFilePath)
                        print("✅ PDF başarıyla kaydedildi: \(pdfFilePath)")
                        
                        // Resmi indir ve kaydet
                        self.downloadImage(from: imageURL) { savedImagePath in
                            if let savedImagePath = savedImagePath {
                                let offlineNews = OfflineNews(
                                    kaynak: "Kaynak Adı",
                                    resim_url: savedImagePath,
                                    baslik: baslik,
                                    tarih: tarih,
                                    haber_url: pdfFilePath.path // PDF dosyasının yolu
                                )
                                self.saveNews(offlineNews)
                            }
                        }
                        
                    } catch {
                        print("❌ PDF kaydedilirken hata oluştu: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    print("❌ PDF oluşturulamadı: \(error.localizedDescription)")
                    // Burada hata mesajını daha detaylı inceleyelim
                }
            }
        }
    }
    
    func get(kaynak: String, haber_url: String, resim_url: String, baslik: String, tarih: String) {
        //self.offlineNewsList.append(OfflineNews(kaynak: kaynak, resim_url: resim_url, baslik: baslik, tarih: tarih, haber_url: haber_url))
        let offlineNews = OfflineNews(
            kaynak: kaynak,
            resim_url: resim_url,
            baslik: baslik,
            tarih: tarih,
            haber_url: haber_url // PDF dosyasının yolu
        )
        self.saveNews(offlineNews)
    }

    // 📌 Belgeler dizinini almak için yardımcı fonksiyon
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

/*struct OfflineNewsView: View {
    let fileName: String
    
    var body: some View {
        WebView(url: OfflineNewsManager.shared.getSavedNewsFilePath(fileName: fileName))
            .edgesIgnoringSafeArea(.all)
    }
}*/

struct OfflineNews: Identifiable, Decodable, Encodable {
    let id = UUID()
    let kaynak: String
    let resim_url: String
    let baslik: String
    let tarih: String
    let haber_url: String
}

struct OfflineNewsListView: View {
    @State private var searchText = ""
    @ObservedObject var offlineNewsManager = OfflineNewsManager.shared
    @State private var isActive: Bool = false
    @State public var haber: String
    
    
    var filteredNews: [OfflineNews] {
        if searchText.isEmpty {
            return offlineNewsManager.offlineNewsList
        } else {
            return offlineNewsManager.offlineNewsList.filter { $0.baslik.localizedCaseInsensitiveContains(searchText) }
        }
    }
    var body: some View {
        NavigationView {
            VStack {
                TextField("Haber Ara", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {offlineNewsManager.deleteAllSavedNews() }){
                    Text("Kaydedilen Haberleri Sil")
                }
                List(filteredNews) { news in
                    VStack(alignment: .center) {
                        
                        Text(news.kaynak)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        AsyncImage(url: URL(string: news.resim_url)) { image in
                            image.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture(count: 1, perform: onTapGesture)
                        } placeholder: {
                            //ProgressView()
                        }
                        
                        Text(news.baslik)
                            .font(.title3)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 5)
                            .onTapGesture(count: 1, perform: onTapGesture)
                        
                        Text(news.tarih)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                    .sheet(isPresented: $isActive) {
                        WebViewContainer(urlString: news.haber_url) {
                            isActive = false
                        }
                    }
                }
            }
            .onAppear {
                // Uygulama açıldığında haberleri yükle
                //offlineNewsManager.deleteAllSavedNews()
                offlineNewsManager.loadSavedNews()
                haber = filteredNews.first?.haber_url ?? ""
            }
            .refreshable {
                offlineNewsManager.loadSavedNews()
            }
        }
        .navigationTitle("Kaydedilen Haberler")
    }
    func onTapGesture(){
        self.isActive.toggle()
    }
}

struct WebView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

// 📌 WebView yüklenme kontrolü için yardımcı class
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    var onLoad: (() -> Void)?
    
    init(onLoad: @escaping () -> Void) {
        self.onLoad = onLoad
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoad?()
    }
}
