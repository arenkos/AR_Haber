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
    @State private var groupedSources: [(lang: String, sources: [String])] = []
    @State private var isLoading = true
    @State var tappedSources: Set<String> = []
    @State private var collapsedSections: Set<String> = []

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading kaynak...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                List {
                    ForEach(groupedSources, id: \.lang) { group in
                        Section(header: languageHeader(for: group.lang, isExpanded: !collapsedSections.contains(group.lang))) {
                            if !collapsedSections.contains(group.lang) {
                                ForEach(group.sources, id: \.self) { category in
                                    HStack {
                                        CachedLogoImage(sourceName: category, height: 20)
                                        Text(category)

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
                    }
                }
            }
        }
        .onAppear {
            fetchSourcesGrouped()
            loadTappedSources()
        }
    }

    // Dil başlığı oluştur
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

    // Dile göre gruplandırılmış kaynakları çek
    func fetchSourcesGrouped() {
        let urlString = "https://armedia.live/fetch_kaynak_grouped.php"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            DispatchQueue.main.async {
                self.isLoading = false
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
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String]] {
                    // Sıralama: TR > EN > FR > diğer
                    let sortOrder: [String: Int] = ["TR": 0, "EN": 1, "FR": 2]
                    let sorted = jsonResponse.sorted { a, b in
                        let orderA = sortOrder[a.key] ?? 99
                        let orderB = sortOrder[b.key] ?? 99
                        return orderA < orderB
                    }

                    DispatchQueue.main.async {
                        self.groupedSources = sorted.map { (lang: $0.key, sources: $0.value) }
                    }
                } else {
                    print("Parsing error: unexpected JSON format")
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

        if let user = authViewModel.user {
            let urlString = "https://armedia.live/arama_kaynak.php?kaynak=\(category)&user=\(user.username)"
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

        let urlString = "https://armedia.live/save_tapped_sources.php"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

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

        let urlString = "https://armedia.live/load_tapped_sources.php?user=\(user.username)"
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
                   let kaynak = jsonResponse["kaynak"] as? [String] {
                    DispatchQueue.main.async {
                        self.tappedSources = Set(kaynak)
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
