//
//  OpenAIRequest.swift
//  AR Haber
//
//  Created by Aren Koş on 12.02.2025.
//


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
    let message: Message
}

struct Message: Codable {
    let content: String
}

class OpenAIService {
    private let apiKey = "API_ANAHTARINIZ" // OpenAI API anahtarınızı buraya ekleyin
    private let apiUrl = "https://api.openai.com/v1/chat/completions"

    func summarize(text: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: apiUrl) else { return }
        
        let prompt = "Bu haberi kısaca özetle: \(text)"
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
}