//
//  CommentsView.swift
//  AR Haber
//
//  Created by Antigravity AI on 7.02.2026.
//

import SwiftUI

// MARK: - Comment Models
struct Comment: Codable, Identifiable {
    let yorum_id: Int
    let kullanici: String
    let ad_soyad: String
    let yorum: String
    let tarih: String
    let haber_url: String
    
    var id: Int { yorum_id }
    
    enum CodingKeys: String, CodingKey {
        case yorum_id, kullanici, ad_soyad, yorum, tarih, haber_url
    }
}

struct CommentsResponse: Codable {
    let status: String
    let count: Int
    let comments: [Comment]
}

struct PostCommentResponse: Codable {
    let status: String
    let message: String
    let yorum_id: Int?
}

// MARK: - Comments ViewModel
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?
    
    func loadComments(newsId: Int) {
        guard let url = URL(string: "https://armedia.live/yorumlar_api.php?id=\(newsId)") else {
            error = "Geçersiz URL"
            return
        }
        
        isLoading = true
        error = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = "Yorumlar yüklenemedi: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.error = "Veri alınamadı"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(CommentsResponse.self, from: data)
                    if response.status == "success" {
                        self?.comments = response.comments
                    } else {
                        self?.error = "Yorumlar alınamadı"
                    }
                } catch {
                    self?.error = "Veri işlenemedi: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func postComment(newsId: Int, comment: String, username: String, newsUrl: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://armedia.live/yorumlar_api.php") else {
            error = "Geçersiz URL"
            completion(false)
            return
        }
        
        isSending = true
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": newsId,
            "yorum": comment,
            "kullanici": username,
            "haber_url": newsUrl
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.error = "İstek oluşturulamadı"
            isSending = false
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isSending = false
                
                if let error = error {
                    self?.error = "Yorum gönderilemedi: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    self?.error = "Yanıt alınamadı"
                    completion(false)
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(PostCommentResponse.self, from: data)
                    if response.status == "success" {
                        completion(true)
                    } else {
                        self?.error = response.message
                        completion(false)
                    }
                } catch {
                    self?.error = "Yanıt işlenemedi"
                    completion(false)
                }
            }
        }.resume()
    }
}

// MARK: - Comments View
struct CommentsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = CommentsViewModel()
    @State private var commentText = ""
    @Environment(\.dismiss) private var dismiss
    
    let newsId: Int
    let newsUrl: String
    
    init(newsId: Int, newsUrl: String = "") {
        self.newsId = newsId
        self.newsUrl = newsUrl
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Yorumlar yükleniyor...")
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Tekrar Dene") {
                            viewModel.loadComments(newsId: newsId)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.comments.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Henüz yorum yok")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if authViewModel.isLoggedIn {
                            Text("İlk yorumu siz yapın!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.comments) { comment in
                                CommentItemView(comment: comment)
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // Comment Input
                if authViewModel.isLoggedIn, let user = authViewModel.user {
                    HStack(spacing: 12) {
                        TextField("Yorumunuzu yazın...", text: $commentText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)
                        
                        Button(action: sendComment) {
                            if viewModel.isSending {
                                ProgressView()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(commentText.isEmpty ? .gray : .blue)
                            }
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                } else {
                    Text("Yorum yapmak için giriş yapın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle("Yorumlar (\(viewModel.comments.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadComments(newsId: newsId)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadComments(newsId: newsId)
        }
    }
    
    private func sendComment() {
        guard let user = authViewModel.user else { return }
        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }
        
        viewModel.postComment(newsId: newsId, comment: trimmedComment, username: user.username, newsUrl: newsUrl) { success in
            if success {
                commentText = ""
                viewModel.loadComments(newsId: newsId)
            }
        }
    }
}

// MARK: - Comment Item View
struct CommentItemView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(String(comment.ad_soyad.isEmpty ? comment.kullanici.prefix(1) : comment.ad_soyad.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.ad_soyad.isEmpty ? comment.kullanici : comment.ad_soyad)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(formatDate(comment.tarih))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(comment.yorum)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        inputFormatter.locale = Locale(identifier: "tr_TR")
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd MMM yyyy, HH:mm"
        outputFormatter.locale = Locale(identifier: "tr_TR")
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    CommentsView(newsId: 1, newsUrl: "")
}
