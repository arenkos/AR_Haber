//
//  OfflineNewsManager.swift
//  AR Haber
//
//  Created by Aren Koş on 12.02.2025.
//

import PDFKit
import SwiftUI
import WebKit

class OfflineNewsManager: ObservableObject {
    static let shared = OfflineNewsManager()
    @Published var offlineNewsList: [OfflineNews] = []  // @Published ekleniyor

    func saveNews(_ news: OfflineNews) {
        DispatchQueue.main.async {
            self.offlineNewsList.insert(news, at: 0)  // Yeni haberi listenin başına ekliyoruz
            print("✅ Haber listeye eklendi: \(news.baslik)")
            print("📋 Toplam kaydedilen haber sayısı: \(self.offlineNewsList.count)")
            self.saveNewsToFile()  // Listeyi kaydediyoruz
        }
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
        guard let url = URL(string: haber_url), let imageURL = URL(string: resim_url) else {
            return
        }
        print("save basıldı")

        let request = URLRequest(url: url)
        webView.load(request)

        DispatchQueue.main.asyncAfter(deadline: .now()) {  // 5 saniye bekleyerek tam yüklenmesini sağlıyoruz
            webView.takeSnapshot(with: nil) { image, error in
                if let image = image {
                    let fileURL = self.getDocumentsDirectory().appendingPathComponent(
                        "\(UUID().uuidString).webarchive")

                    do {
                        try image.pngData()?.write(to: fileURL)
                        print("Sayfa başarıyla kaydedildi: \(fileURL)")

                        // Resmi indir ve kaydet
                        self.downloadImage(from: imageURL) { savedImagePath in
                            if let savedImagePath = savedImagePath {
                                let offlineNews = OfflineNews(
                                    kaynak: "Kaynak Adı", resim_url: savedImagePath, baslik: baslik,
                                    tarih: tarih, haber_url: fileURL.path)
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
        let fileManager = FileManager.default

        // 🔧 Eğer URL yerel bir dosya yolu ise, kopyala
        if url.isFileURL || url.scheme == nil {
            // Yerel dosya - kopyala
            let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let uniqueFileName = "offline_\(UUID().uuidString).\(fileExtension)"
            let destinationURL = getDocumentsDirectory().appendingPathComponent(uniqueFileName)

            do {
                // Dosyanın var olup olmadığını kontrol et
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.copyItem(at: url, to: destinationURL)
                    print("✅ Yerel resim kopyalandı: \(uniqueFileName)")
                    completion(destinationURL.path)
                } else {
                    print("❌ Yerel dosya bulunamadı: \(url.path)")
                    completion(nil)
                }
            } catch {
                print("❌ Yerel resim kopyalanırken hata: \(error)")
                completion(nil)
            }
            return
        }

        // 🌐 URL uzak bir sunucudaysa, indir
        let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let uniqueFileName = "offline_\(UUID().uuidString).\(fileExtension)"
        let destinationURL = getDocumentsDirectory().appendingPathComponent(uniqueFileName)

        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let location = location, error == nil else {
                print(
                    "❌ Offline resim indirilirken hata: \(error?.localizedDescription ?? "Bilinmeyen hata")"
                )
                completion(nil)
                return
            }

            do {
                try fileManager.moveItem(at: location, to: destinationURL)

                // Kaydedilen resmin varlığını kontrol et
                if UIImage(contentsOfFile: destinationURL.path) != nil {
                    print("✅ Offline resim başarıyla kaydedildi: \(uniqueFileName)")
                } else {
                    print("⚠️ Offline resim yüklenemedi")
                }

                completion(destinationURL.path)
            } catch {
                print("❌ Offline resim kaydedilirken hata: \(error)")
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
            return  // Dosya zaten oluşturuldu, geri dön
        }

        do {
            let data = try Data(contentsOf: fileURL)
            offlineNewsList = try JSONDecoder().decode([OfflineNews].self, from: data)
            print("✅ Haberler başarıyla yüklendi.")
            print("📋 Toplam haber sayısı: \(offlineNewsList.count)")

            // Debug: Her haberin özet durumunu kontrol et
            for (index, news) in offlineNewsList.enumerated() {
                print("📰 Haber \(index + 1): \(news.baslik)")
                if let ozet = news.ozet {
                    print("   ✅ Özet var (\(ozet.count) karakter)")
                } else {
                    print("   ❌ Özet yok")
                }
            }
        } catch {
            print("❌ Haber dosyaları yüklenirken hata oluştu: \(error)")
        }
    }

    func deleteAllSavedNews() {
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsDirectory()

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory, includingPropertiesForKeys: nil)

            // .webarchive ve resim dosyalarını sil
            for fileURL in fileURLs {
                if fileURL.pathExtension == "webarchive" || fileURL.pathExtension == "pdf"
                    || fileURL.pathExtension == "jpg" || fileURL.pathExtension == "png"
                    || fileURL.pathExtension == "jpeg"
                {
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {  // Sayfanın yüklenmesini bekliyoruz
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
        guard let url = URL(string: haber_url), let imageURL = URL(string: resim_url) else {
            return
        }

        let request = URLRequest(url: url)
        webView.load(request)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("✅ Web sayfası yüklendi, PDF kaydediliyor...")

            let pdfFilePath = self.getDocumentsDirectory().appendingPathComponent(
                "\(UUID().uuidString).pdf")

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
                                    haber_url: pdfFilePath.path  // PDF dosyasının yolu
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
        let webView = WKWebView()
        guard let url = URL(string: haber_url) else {
            print("❌ Geçersiz haber URL'si: \(haber_url)")
            return
        }
        print("📥 Haber kaydediliyor: \(baslik)")

        let request = URLRequest(url: url)
        webView.load(request)

        // Önce özeti indir
        downloadSummary(for: haber_url) { [weak self] summary in
            guard let self = self else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                webView.takeSnapshot(with: nil) { image, error in
                    if let image = image {
                        let fileURL = self.getDocumentsDirectory().appendingPathComponent(
                            "\(UUID().uuidString).webarchive")

                        do {
                            try image.pngData()?.write(to: fileURL)
                            print("✅ Sayfa başarıyla kaydedildi: \(fileURL)")

                            // Resim URL'sinin yerel dosya mı yoksa web URL'si mi olduğunu kontrol et
                            if resim_url.hasPrefix("http://") || resim_url.hasPrefix("https://") {
                                // Web URL'si - indir
                                guard let imageURL = URL(string: resim_url) else {
                                    print("❌ Geçersiz resim URL'si: \(resim_url)")
                                    return
                                }

                                self.downloadImage(from: imageURL) { savedImagePath in
                                    if let savedImagePath = savedImagePath {
                                        DispatchQueue.main.async {
                                            let offlineNews = OfflineNews(
                                                kaynak: kaynak,
                                                resim_url: savedImagePath,
                                                baslik: baslik,
                                                tarih: tarih,
                                                haber_url: haber_url,
                                                ozet: summary
                                            )
                                            self.saveNews(offlineNews)
                                            print("✅ Haber özeti ile birlikte kaydedildi!")
                                        }
                                    } else {
                                        print("❌ Resim kaydedilemedi")
                                    }
                                }
                            } else {
                                // Yerel dosya yolu - kopyala
                                print("📁 Yerel resim tespit edildi: \(resim_url)")
                                let localPath = resim_url.replacingOccurrences(
                                    of: "file://", with: "")

                                if FileManager.default.fileExists(atPath: localPath) {
                                    let fileExtension =
                                        URL(fileURLWithPath: localPath).pathExtension.isEmpty
                                        ? "jpg" : URL(fileURLWithPath: localPath).pathExtension
                                    let uniqueFileName =
                                        "offline_\(UUID().uuidString).\(fileExtension)"
                                    let destinationURL = self.getDocumentsDirectory()
                                        .appendingPathComponent(uniqueFileName)

                                    do {
                                        try FileManager.default.copyItem(
                                            at: URL(fileURLWithPath: localPath), to: destinationURL)
                                        print("✅ Yerel resim kopyalandı: \(uniqueFileName)")

                                        DispatchQueue.main.async {
                                            let offlineNews = OfflineNews(
                                                kaynak: kaynak,
                                                resim_url: destinationURL.path,
                                                baslik: baslik,
                                                tarih: tarih,
                                                haber_url: haber_url,
                                                ozet: summary
                                            )
                                            self.saveNews(offlineNews)
                                            print("✅ Haber özeti ile birlikte kaydedildi!")
                                        }
                                    } catch {
                                        print("❌ Resim kopyalanırken hata: \(error)")
                                    }
                                } else {
                                    print("❌ Yerel resim dosyası bulunamadı: \(localPath)")
                                }
                            }

                        } catch {
                            print("❌ WebArchive kaydedilirken hata oluştu: \(error)")
                        }
                    } else {
                        print(
                            "❌ Snapshot alınamadı: \(error?.localizedDescription ?? "Bilinmeyen hata")"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Özet İndirme Fonksiyonu
    func downloadSummary(for haberURL: String, completion: @escaping (String?) -> Void) {
        guard
            let encodedURL = haberURL.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed),
            let url = URL(
                string:
                    "https://www.aryazilimdanismanlik.com/armedya/ozet_olustur.php?haber_url=\(encodedURL)"
            )
        else {
            print("❌ Özet URL'si oluşturulamadı")
            completion(nil)
            return
        }

        print("📥 Özet indiriliyor: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Özet indirme hatası: \(error?.localizedDescription ?? "Bilinmeyen")")
                completion(nil)
                return
            }

            // Debug: Response'u yazdır
            if let responseString = String(data: data, encoding: .utf8) {
                print(
                    "📝 Özet API Response (ilk 200 karakter): \(String(responseString.prefix(200)))")
            }

            do {
                let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: data)

                if summaryResponse.success, let summaryData = summaryResponse.data {
                    print("✅ Özet başarıyla indirildi!")
                    completion(summaryData.ozet)
                } else {
                    print("⚠️ Özet oluşturulamadı: \(summaryResponse.error ?? "Bilinmeyen")")
                    completion(nil)
                }
            } catch {
                print("❌ Özet JSON decode hatası: \(error)")
                completion(nil)
            }
        }.resume()
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
    var ozet: String?  // Özet alanı eklendi

    enum CodingKeys: String, CodingKey {
        case kaynak, resim_url, baslik, tarih, haber_url, ozet
    }
}

struct OfflineNewsListView: View {
    @State private var searchText = ""
    @ObservedObject var offlineNewsManager = OfflineNewsManager.shared
    @State private var isActive: Bool = false
    @State private var selectedNews: OfflineNews?
    @State private var selectedSummaryNews: OfflineNews?  // Özet için ayrı state

    var filteredNews: [OfflineNews] {
        if searchText.isEmpty {
            return offlineNewsManager.offlineNewsList
        } else {
            return offlineNewsManager.offlineNewsList.filter {
                $0.baslik.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
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
    var body: some View {
        NavigationView {
            VStack {
                TextField("Haber Ara", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: { offlineNewsManager.deleteAllSavedNews() }) {
                    Text("Kaydedilen Haberleri Sil")
                }
                List(filteredNews) { news in
                    OfflineNewsRow(
                        news: news,
                        mapSource: mapSource,
                        onTapGesture: {
                            selectedNews = news
                            isActive = true
                        },
                        onSummaryTap: {
                            selectedSummaryNews = news  // Ayrı state kullan
                        }
                    )
                }
            }
            .onAppear {
                offlineNewsManager.loadSavedNews()
            }
            .refreshable {
                offlineNewsManager.loadSavedNews()
            }
            .sheet(isPresented: $isActive) {
                if let news = selectedNews {
                    WebViewContainer(urlString: news.haber_url) {
                        isActive = false
                    }
                }
            }
            .sheet(item: $selectedSummaryNews) { news in
                OfflineHaberOzetiView(
                    news: news,
                    mapSource: mapSource
                )
            }
        }
        .navigationTitle("Kaydedilen Haberler")
    }
    func onTapGesture() {
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

// MARK: - Offline Haber Satırı (Kaydırmalı)
struct OfflineNewsRow: View {
    let news: OfflineNews
    let mapSource: (String) -> String
    let onTapGesture: () -> Void
    let onSummaryTap: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Kaynak Logosu
            Image(mapSource(news.kaynak))
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)

            // Haber Görseli
            if let uiImage = UIImage(contentsOfFile: news.resim_url) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture(perform: onTapGesture)
            }

            // Başlık
            Text(news.baslik)
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 5)
                .onTapGesture(perform: onTapGesture)

            // Tarih
            Text(news.tarih)
                .font(.footnote)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)

            // Özet durumu göstergesi
            if news.ozet != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Özet mevcut")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .offset(x: dragOffset)
        .background(
            // Sola kaydırma göstergesi
            HStack {
                Spacer()
                if dragOffset < -50 {
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Özet")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 20)
                    .frame(width: abs(dragOffset))
                    .background(news.ozet != nil ? Color.blue : Color.orange)
                }
            }
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Sadece sola kaydırmaya izin ver
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        // 100 pikselden fazla sola kaydırıldıysa özet ekranını aç
                        onSummaryTap()
                    }
                    // Animasyonlu olarak sıfırla
                    withAnimation {
                        dragOffset = 0
                    }
                }
        )
    }
}

// MARK: - Offline Haber Özeti Görünümü
struct OfflineHaberOzetiView: View {
    @Environment(\.dismiss) var dismiss
    let news: OfflineNews
    let mapSource: (String) -> String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Haber Görseli
                    if let uiImage = UIImage(contentsOfFile: news.resim_url) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        // Resim yüklenemezse placeholder göster
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }

                    // Kaynak Logosu ve Tarih
                    HStack {
                        let kaynak = mapSource(news.kaynak)
                        Image(kaynak)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)

                        Text(news.kaynak)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        Text(news.tarih)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Haber Başlığı
                    Text(news.baslik)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    // Özet Başlığı
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("AI Özeti")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }

                    // Özet İçeriği
                    if let ozet = news.ozet, !ozet.isEmpty {
                        Text(ozet)
                            .font(.body)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Özet bulunamadı")
                                    .foregroundColor(.orange)
                                    .font(.headline)
                            }

                            Text(
                                "Bu haber kaydedilirken özet oluşturulamadı veya internet bağlantısı yoktu."
                            )
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 20)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Haber Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
