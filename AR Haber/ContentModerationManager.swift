//
//  ContentModerationManager.swift
//  AR Haber
//
//  Created by Antigravity AI on 11.02.2026.
//

import SwiftUI

/// Manages content moderation: blocked users, content reporting, and word filtering
class ContentModerationManager: ObservableObject {
    static let shared = ContentModerationManager()

    private let blockedUsersKey = "blockedUsers"

    @Published var blockedUsers: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(blockedUsers), forKey: blockedUsersKey)
        }
    }

    // Prohibited words list for basic content filtering
    private let prohibitedWords: [String] = [
        // Türkçe küfür ve hakaret kelimeleri
        "amk", "aq", "orospu", "piç", "siktir", "s1ktir",
        "yavşak", "götveren", "pezevenk", "kaltak", "fahişe",
        // Nefret söylemi
        "terörist", "ölüm tehdidi", "bombala", "öldürürüm",
        // İngilizce
        "fuck", "shit", "bitch", "asshole", "nigger",
    ]

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: blockedUsersKey) ?? []
        self.blockedUsers = Set(saved)
    }

    // MARK: - Block/Unblock

    func isBlocked(_ username: String) -> Bool {
        return blockedUsers.contains(username.lowercased())
    }

    func blockUser(_ username: String) {
        blockedUsers.insert(username.lowercased())
    }

    func unblockUser(_ username: String) {
        blockedUsers.remove(username.lowercased())
    }

    // MARK: - Content Filtering

    /// Returns true if text contains prohibited content
    func containsProhibitedContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        for word in prohibitedWords {
            if lowercased.contains(word) {
                return true
            }
        }
        return false
    }

    // MARK: - Report Content

    /// Report a comment or message to the server
    func reportContent(
        type: String,  // "comment" or "message"
        contentId: Int,
        reason: String,
        reporterUsername: String,
        reportedUsername: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "https://armedia.live/report_content.php") else {
            completion(false, "Geçersiz URL")
            return
        }

        let body: [String: Any] = [
            "type": type,
            "content_id": contentId,
            "reason": reason,
            "reporter": reporterUsername,
            "reported_user": reportedUsername,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "İstek oluşturulamadı")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Hata: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    completion(false, "Yanıt alınamadı")
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let status = json["status"] as? String
                    {
                        completion(
                            status == "success", json["message"] as? String ?? "Bilinmeyen durum")
                    } else {
                        completion(false, "Yanıt formatı hatalı")
                    }
                } catch {
                    completion(false, "Yanıt işlenemedi")
                }
            }
        }.resume()
    }

    /// Block a user on the server side as well
    func blockUserOnServer(
        blockerUsername: String,
        blockedUsername: String,
        completion: @escaping (Bool) -> Void
    ) {
        // First block locally
        blockUser(blockedUsername)

        guard let url = URL(string: "https://armedia.live/block_user.php") else {
            completion(true)  // Local block succeeded
            return
        }

        let body: [String: Any] = [
            "blocker": blockerUsername,
            "blocked": blockedUsername,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(true)  // Local block succeeded
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                completion(true)
            }
        }.resume()
    }
}
