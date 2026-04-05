//
//  Kategori.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//

import SwiftUI
import Combine
import GoogleMobileAds

struct Kategori: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var groupedCategories: [(lang: String, sources: [String])] = []
    @State private var collapsedSections: Set<String> = []
    @State private var isLoading = true
    @State var tappedCategories: Set<String> = []
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading categories...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                List {
                    ForEach(groupedCategories, id: \.lang) { group in
                        Section(header: languageHeader(for: group.lang, isExpanded: !collapsedSections.contains(group.lang))) {
                            if !collapsedSections.contains(group.lang) {
                                ForEach(group.sources, id: \.self) { category in
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
                    }
                }
            }
        }
        .onAppear {
            loadSelectedCategories() // Load selected categories from the database
            fetchCategories() // Fetch the available categories
        }
    }
    
    @ViewBuilder
    func languageHeader(for langCode: String, isExpanded: Bool) -> some View {
        HStack(spacing: 6) {
            Text(flagEmoji(for: langCode))
                .font(.headline)
            Text(langCode)
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                if collapsedSections.contains(langCode) {
                    collapsedSections.remove(langCode)
                } else {
                    collapsedSections.insert(langCode)
                }
            }
        }
    }

    func flagEmoji(for langCode: String) -> String {
        switch langCode {
        case "TR": return "🇹🇷"
        case "EN": return "🇬🇧"
        case "FR": return "🇫🇷"
        case "DE": return "🇩🇪"
        case "ES": return "🇪🇸"
        case "AR": return "🇸🇦"
        default: return "🌐"
        }
    }

    // Fetch categories from the server
    func fetchCategories() {
        let urlString = "https://armedia.live/fetch_kategori_grouped.php"
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }
            if let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String]] {
                        let sortOrder: [String: Int] = ["TR": 0, "EN": 1, "FR": 2]
                        let sorted = jsonResponse.sorted { a, b in
                            let orderA = sortOrder[a.key] ?? 99
                            let orderB = sortOrder[b.key] ?? 99
                            return orderA < orderB
                        }
                        DispatchQueue.main.async {
                            self.groupedCategories = sorted.map { (lang: $0.key, sources: $0.value) }
                        }
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                }
            }
        }
        task.resume()
    }
    
    // Toggle the bell icon and update the selected categories
    func toggleBell(for category: String) {
        if tappedCategories.contains(category) {
            tappedCategories.remove(category)
        } else {
            tappedCategories.insert(category)
        }
        
        //saveSelectedCategories() // Save the updated categories to the database
        
        if let user = authViewModel.user {
            let urlString = "https://armedia.live/arama_kategori.php?kategori=\(category)&user=\(user.username)"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error == nil { print("Request successful for category: \(category)") }
            }
            task.resume()
        }
    }
    
    // Save selected categories to the database
    func saveSelectedCategories() {
        guard let user = authViewModel.user else { return }
        
        let selectedCategoriesArray = Array(tappedCategories)
        let categoriesString = selectedCategoriesArray.joined(separator: ",")
        
        let urlString = "https://armedia.live/save_tapped_categories.php"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Prepare body data
        let bodyString = "user=\(user.username)&categories=\(categoriesString)"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let _ = data else {
                print("No data received")
                return
            }
            
            print("Selected categories saved to the database")
        }
        
        task.resume()
    }
    
    // Load selected categories from the database
    func loadSelectedCategories() {
        guard let user = authViewModel.user else { return }
        
        let urlString = "https://armedia.live/load_tapped_categories.php?user=\(user.username)"
        guard let url = URL(string: urlString) else { return }
        
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
                   let categories = jsonResponse["categories"] as? [String] { // ✅ Dizi olarak parse et
                    DispatchQueue.main.async {
                        self.tappedCategories = Set(categories) // ✅ Direkt dizi olarak ata
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
