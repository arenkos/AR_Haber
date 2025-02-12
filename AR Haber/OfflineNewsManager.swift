import SwiftUI
import WebKit

class OfflineNewsManager {
    static let shared = OfflineNewsManager()
    
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
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}