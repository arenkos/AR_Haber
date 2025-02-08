//
//  Kaynak.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//

import SwiftUI
import WebKit
import Combine
import GoogleMobileAds

struct Kaynak: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var kaynak: [String] = [] // To hold fetched kaynak
    @State private var isLoading = true // To show loading state
    @State var tappedSources: Set<String> = [] // To keep track of tapped kaynak

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
                ProgressView("Loading kaynak...") // Loading indicator
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                List(kaynak, id: \.self) { category in
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
                            Image(systemName: tappedSources.contains(category) ? "bell.fill" : "bell")
                                .foregroundColor(tappedSources.contains(category) ? .yellow : .gray)
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchSources()
            loadTappedSources() // Load selected kaynak from the database
        }
    }

    // Function to fetch kaynak
    func fetchSources() {
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/fetch_kaynak.php"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyString = ""
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
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
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let kaynak = jsonResponse["kaynak"] as? [String] {
                    DispatchQueue.main.async {
                        self.kaynak = kaynak // Update the UI with fetched kaynak
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
        if tappedSources.contains(category) {
            tappedSources.remove(category)
        } else {
            tappedSources.insert(category)
        }
        
        //saveTappedSources() // Save the tapped kaynak to the database
        
        if let user = authViewModel.user {
            let urlString = "https://www.aryazilimdanismanlik.com/armedya/arama_kaynak.php?kaynak=\(category)&user=\(user.username)"
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
                
                print("Request successful for category: \(category)")
            }
            
            task.resume()
        }
    }

    // Save tapped kaynak to the database
    func saveTappedSources() {
        guard let user = authViewModel.user else {
            return
        }
        
        let selectedSourcesArray = Array(tappedSources)
        let kaynakString = selectedSourcesArray.joined(separator: ",")
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/save_tapped_sources.php"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Prepare body data
        let bodyString = "user=\(user.username)&kaynak=\(kaynakString)"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let _ = data else {
                print("No data received")
                return
            }
            
            print("Tapped kaynak saved")
        }
        
        task.resume()
    }

    // Load tapped kaynak from the database
    func loadTappedSources() {
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
                   let kaynak = jsonResponse["kaynak"] as? [String] { // ✅ Diziyi doğru parse et
                    DispatchQueue.main.async {
                        self.tappedSources = Set(kaynak) // ✅ Direkt Set içine ata
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
}
