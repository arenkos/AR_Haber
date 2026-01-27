//
//  OpenAIRequest.swift
//  AR Haber
//
//  Created by Aren Koş on 12.02.2025.
//

import SwiftUI
import Foundation

struct OpenAIRequest: Codable {
    let model: String
    let messages: [[String: String]]
    let temperature: Double
    let max_tokens: Int
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message_Summary
}

struct Message_Summary: Codable {
    let content: String
}

class OpenAIService {
    private let apiKey = "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" // OpenAI API anahtarınızı buraya ekleyin
    private let apiUrl = "https://api.openai.com/v1/chat/completions"

    func summarize(text: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: apiUrl) else { return }
        
        let prompt = "Bu sitedeki haberi kısaca özetle: \(text)"
        let requestData = OpenAIRequest(
            model: "gpt-3.5-turbo", 
            messages: [["role": "user", "content": prompt]], 
            temperature: 0.7, 
            max_tokens: 100
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(requestData)
            request.httpBody = jsonData
        } catch {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(result.choices.first?.message.content)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    func sendChatMessage(text: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: apiUrl) else { return }
        
        let requestData = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [["role": "user", "content": text]],
            temperature: 0.7,
            max_tokens: 500
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(requestData)
            request.httpBody = jsonData
        } catch {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(result.choices.first?.message.content)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

struct NewsSummaryView: View {
    let newsText: String
    @State private var summary: String = ""
    @State private var fullSummary: String = ""
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Haber Özeti")
                .font(.title)
                .bold()
            
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("AI özet hazırlıyor...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                Text(summary)
                    .font(.body)
                    .padding()
                    .animation(.default, value: summary)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            OpenAIService().summarize(text: newsText) { result in
                isLoading = false
                if let result = result {
                    fullSummary = result
                    startTypewriterEffect()
                } else {
                    fullSummary = "Özet oluşturulamadı."
                    summary = fullSummary
                }
            }
        }
    }
    
    private func startTypewriterEffect() {
        summary = ""
        var charIndex = 0
        let characters = Array(fullSummary)
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if charIndex < characters.count {
                summary.append(characters[charIndex])
                charIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}
