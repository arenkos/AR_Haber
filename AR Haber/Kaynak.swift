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
