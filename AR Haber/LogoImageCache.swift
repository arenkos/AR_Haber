//
//  LogoImageCache.swift
//  AR Haber
//
//  Kaynak logoları için iki katmanlı önbellekleme:
//  1. Bellek cache (NSCache) → çok hızlı, uygulama açıkken geçerli
//  2. Disk cache (Caches dizini) → kalıcı, her oturumda geçerli
//
//  Yeni bir kaynak sunucuya eklendiğinde logo otomatik olarak
//  çekilir ve önbelleğe alınır; hardcoded eşleşme gerekmez.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - URL Yardımcı Fonksiyonu

/// Kaynak adını sunucudaki logo dosya adına dönüştürür.
/// Örn: "CNN TÜRK" → "cnn_turk"  |  "A HABER" → "a_haber"
func logoFileName(for sourceName: String) -> String {
    let turkishMap: [(Character, Character)] = [
        ("ş", "s"), ("Ş", "s"),
        ("ğ", "g"), ("Ğ", "g"),
        ("ü", "u"), ("Ü", "u"),
        ("ö", "o"), ("Ö", "o"),
        ("ç", "c"), ("Ç", "c"),
        ("ı", "i"), ("İ", "i")
    ]
    var result = sourceName.lowercased()
    for (tr, en) in turkishMap {
        result = result.replacingOccurrences(of: String(tr), with: String(en))
    }
    // Sadece harf ve rakamlar kalsın; boşluk, nokta ve özel karakterler silinir
    result = result.filter { $0.isLetter || $0.isNumber }
    return result
}

func logoUrl(for sourceName: String) -> URL? {
    let file = logoFileName(for: sourceName)
    return URL(string: "https://armedia.live/logo/\(file).png")
}

// MARK: - Logo Cache Servisi

final class LogoImageCache {
    static let shared = LogoImageCache()
    private init() {}

    // Bellek cache
    private let memoryCache = NSCache<NSString, UIImage>()

    // Disk cache dizini
    private var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("LogoCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Okuma

    func image(for key: String) -> UIImage? {
        // 1. Bellek cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        // 2. Disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key + ".png")
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }
        return nil
    }

    // MARK: Yazma

    func store(_ image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
        let fileURL = cacheDirectory.appendingPathComponent(key + ".png")
        DispatchQueue.global(qos: .utility).async {
            try? image.pngData()?.write(to: fileURL)
        }
    }

    // MARK: İndirme (cache-miss durumunda)

    func fetchIfNeeded(sourceName: String, completion: @escaping (UIImage?) -> Void) {
        let key = logoFileName(for: sourceName)
        if let cached = image(for: key) {
            completion(cached)
            return
        }
        guard let url = logoUrl(for: sourceName) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.store(img, for: key)
            DispatchQueue.main.async { completion(img) }
        }.resume()
    }
}

// MARK: - CachedLogoImage SwiftUI View

/// Kullanım: CachedLogoImage(sourceName: news.kaynak, height: 24)
struct CachedLogoImage: View {
    let sourceName: String
    var height: CGFloat = 24

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            } else {
                // Yüklenirken yer tutucu
                Color.clear
                    .frame(height: height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard image == nil else { return }
        LogoImageCache.shared.fetchIfNeeded(sourceName: sourceName) { fetched in
            self.image = fetched
        }
    }
}
