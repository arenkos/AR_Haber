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

    private let moderationManager = ContentModerationManager.shared

    /// Filtered comments excluding blocked users
    var filteredComments: [Comment] {
        comments.filter { !moderationManager.isBlocked($0.kullanici) }
    }

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

    func postComment(
        newsId: Int, comment: String, username: String, newsUrl: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Content filter check
        if moderationManager.containsProhibitedContent(comment) {
            error = "Yorumunuz uygunsuz içerik barındırmaktadır. Lütfen düzenleyip tekrar deneyin."
            completion(false)
            return
        }

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
            "haber_url": newsUrl,
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
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var showReportSuccess = false
    @State private var showBlockSuccess = false
    @State private var showContentFilterAlert = false
    @State private var selectedComment: Comment? = nil
    @State private var reportReason = ""
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
                } else if viewModel.filteredComments.isEmpty {
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
                            ForEach(viewModel.filteredComments) { comment in
                                CommentItemView(
                                    comment: comment,
                                    isLoggedIn: authViewModel.isLoggedIn,
                                    currentUsername: authViewModel.user?.username ?? "",
                                    onReport: {
                                        selectedComment = comment
                                        showReportAlert = true
                                    },
                                    onBlock: {
                                        selectedComment = comment
                                        showBlockAlert = true
                                    }
                                )
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
                        .disabled(
                            commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || viewModel.isSending)
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
            .navigationTitle("Yorumlar (\(viewModel.filteredComments.count))")
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
            // MARK: - Report Alert
            .alert("Yorumu Şikayet Et", isPresented: $showReportAlert) {
                TextField("Şikayet nedeniniz...", text: $reportReason)
                Button("Şikayet Et", role: .destructive) {
                    reportSelectedComment()
                }
                Button("İptal", role: .cancel) {
                    reportReason = ""
                }
            } message: {
                Text(
                    "Bu yorumu neden şikayet etmek istiyorsunuz? Şikayetiniz 24 saat içinde incelenecektir."
                )
            }
            // MARK: - Block Alert
            .alert("Kullanıcıyı Engelle", isPresented: $showBlockAlert) {
                Button("Engelle", role: .destructive) {
                    blockSelectedUser()
                }
                Button("İptal", role: .cancel) {}
            } message: {
                if let comment = selectedComment {
                    Text(
                        "\(comment.ad_soyad.isEmpty ? comment.kullanici : comment.ad_soyad) adlı kullanıcıyı engellemek istediğinize emin misiniz? Bu kullanıcının yorumlarını ve mesajlarını göremezsiniz."
                    )
                }
            }
            // MARK: - Success Alerts
            .alert("Şikayet Gönderildi", isPresented: $showReportSuccess) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Şikayetiniz alındı. En kısa sürede incelenecektir. Teşekkür ederiz.")
            }
            .alert("Kullanıcı Engellendi", isPresented: $showBlockSuccess) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Kullanıcı engellendi. Bu kullanıcının içeriklerini artık görmeyeceksiniz.")
            }
            // MARK: - Content Filter Alert
            .alert("Uygunsuz İçerik", isPresented: $showContentFilterAlert) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(
                    "Yorumunuz uygunsuz içerik barındırmaktadır. Lütfen düzenleyip tekrar deneyin.")
            }
        }
        .onAppear {
            viewModel.loadComments(newsId: newsId)
            // Sunucudan engellenen kullanıcıları yükle
            if let user = authViewModel.user {
                ContentModerationManager.shared.loadBlockedUsers(username: user.username)
            }
        }
    }

    private func sendComment() {
        guard let user = authViewModel.user else { return }
        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }

        // Check content filter
        if ContentModerationManager.shared.containsProhibitedContent(trimmedComment) {
            showContentFilterAlert = true
            return
        }

        viewModel.postComment(
            newsId: newsId, comment: trimmedComment, username: user.username, newsUrl: newsUrl
        ) { success in
            if success {
                commentText = ""
                viewModel.loadComments(newsId: newsId)
            }
        }
    }

    private func reportSelectedComment() {
        guard let comment = selectedComment,
            let user = authViewModel.user
        else { return }

        let reason = reportReason.isEmpty ? "Uygunsuz içerik" : reportReason

        ContentModerationManager.shared.reportContent(
            type: "comment",
            contentId: comment.yorum_id,
            reason: reason,
            reporterUsername: user.username,
            reportedUsername: comment.kullanici
        ) { success, _ in
            reportReason = ""
            selectedComment = nil
            if success {
                showReportSuccess = true
            }
        }
    }

    private func blockSelectedUser() {
        guard let comment = selectedComment,
            let user = authViewModel.user
        else { return }

        ContentModerationManager.shared.blockUserOnServer(
            blockerUsername: user.username,
            blockedUsername: comment.kullanici
        ) { success in
            selectedComment = nil
            if success {
                showBlockSuccess = true
                // Refresh to hide blocked user's comments
                viewModel.objectWillChange.send()
            }
        }
    }
}

// MARK: - Comment Item View
struct CommentItemView: View {
    let comment: Comment
    let isLoggedIn: Bool
    let currentUsername: String
    var onReport: () -> Void
    var onBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Text(
                        String(
                            comment.ad_soyad.isEmpty
                                ? comment.kullanici.prefix(1) : comment.ad_soyad.prefix(1)
                        ).uppercased()
                    )
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

                // Report/Block menu — only show if logged in and not own comment
                if isLoggedIn && comment.kullanici != currentUsername {
                    Menu {
                        Button(role: .destructive) {
                            onReport()
                        } label: {
                            Label("Şikayet Et", systemImage: "flag.fill")
                        }

                        Button(role: .destructive) {
                            onBlock()
                        } label: {
                            Label("Kullanıcıyı Engelle", systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
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
