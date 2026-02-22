import Foundation
import SwiftUI
import WebKit

// PreferenceKey for tracking scroll position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Mesaj yapısı
struct Message: Identifiable, Codable {
    let id: Int
    let sender_id: String
    let receiver_id: String
    let text: String
    let timestamp: String
    let haber_baslik: String?
    let haber_resim: String?

    enum CodingKeys: String, CodingKey {
        case id, sender_id, receiver_id, text, timestamp, haber_baslik, haber_resim
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        sender_id = try container.decode(String.self, forKey: .sender_id)
        receiver_id = try container.decode(String.self, forKey: .receiver_id)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        haber_baslik = try container.decodeIfPresent(String.self, forKey: .haber_baslik)
        haber_resim = try container.decodeIfPresent(String.self, forKey: .haber_resim)
    }
}

// Kullanıcı yapısı
struct Usr: Identifiable, Codable, Equatable {
    var id: Int
    var email: String
    var telefon: String
    var username: String
    var ad_soyad: String

    enum CodingKeys: String, CodingKey {
        case id, email, telefon, username, ad_soyad
    }

    init(id: Int, email: String, telefon: String, username: String, ad_soyad: String) {
        self.id = id
        self.email = email
        self.telefon = telefon
        self.username = username
        self.ad_soyad = ad_soyad
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.username = try container.decode(String.self, forKey: .username)
        self.ad_soyad = try container.decode(String.self, forKey: .ad_soyad)

        if let phoneString = try? container.decode(String.self, forKey: .telefon) {
            self.telefon = phoneString
        } else if let phoneInt = try? container.decode(Int.self, forKey: .telefon) {
            self.telefon = String(phoneInt)
        } else {
            self.telefon = "Geçersiz Telefon"
        }
    }
}

class ChatWebSocketService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    @Published var messages: [Message] = []

    func connect() {
        let url = URL(string: "wss://armedia.live:8880")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }

    func sendMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Mesaj gönderme hatası: \(error)")
            }
        }
    }

    func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        // Eğer gelen veri JSON ise çözümle
                        let decoder = JSONDecoder()
                        if let data = text.data(using: .utf8) {
                            do {
                                let decodedMessage = try decoder.decode(Message.self, from: data)
                                self?.messages.append(decodedMessage)
                            } catch {
                                print("JSON çözümleme hatası: \(error)")
                            }
                        }
                    }
                default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("Mesaj alma hatası: \(error)")
            }
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

// Sohbet servisi
class ChatService: ObservableObject {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Published var messages: [Message] = []
    @Published var searchResults: [Usr] = []
    @Published var recentChats: [Usr] = []
    @Published var selectedReceiver: Usr?
    @Published var searchText: String = ""

    func fetchMessages(senderId: String, receiverId: String) {
        guard
            let url = URL(
                string:
                    "https://armedia.live/get_messages.php?sender_id=\(senderId)&receiver_id=\(receiverId)"
            )
        else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                print("Veri alınamadı: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                return
            }

            do {
                let messages = try JSONDecoder().decode([Message].self, from: data)
                DispatchQueue.main.async {
                    self.messages = messages
                    //print("Mesajlar alındı: \(messages)") // Hata ayıklama için
                }
            } catch {
                print("Mesajlar alınamadı: \(error)")
            }
        }.resume()
    }

    func sendMessage(
        senderId: String, receiverId: String, text: String, deviceToken: String,
        haberBaslik: String? = nil, haberResim: String? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let url = URL(string: "https://armedia.live/send_message.php")
        else {
            completion(false, "URL Hatası")
            return
        }

        // Production ortamını belirle
        #if DEBUG
            let isProduction = false
        #else
            let isProduction = true
        #endif

        var body: [String: Any] = [
            "sender_id": senderId,
            "receiver_id": receiverId,
            "text": text,
            "device_token": deviceToken,
            "is_production": isProduction,
        ]

        // Haber bilgilerini ekle (varsa)
        if let baslik = haberBaslik {
            body["haber_baslik"] = baslik
        }
        if let resim = haberResim {
            body["haber_resim"] = resim
        }

        let jsonData = try? JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Mesaj gönderme hatası: \(error.localizedDescription)")
                completion(false, "Mesaj gönderme hatası: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Mesaj gönderme yanıtı: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    if let data = data {
                        // PHP'den gelen yanıtı al
                        if let jsonResponse = try? JSONSerialization.jsonObject(
                            with: data, options: []) as? [String: Any],
                            let status = jsonResponse["status"] as? String,
                            let message = jsonResponse["message"] as? String
                        {
                            if status == "success" {
                                print("Mesaj başarıyla gönderildi.")
                                completion(true, message)
                            } else {
                                print("Bildirim gönderme hatası: \(message)")
                                completion(false, message)
                            }
                        }
                    }
                } else {
                    completion(false, "Mesaj gönderilemedi.")
                }
            }
        }.resume()
    }

    func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            print("Arama sorgusu boş, sonuçlar sıfırlandı.")
            return
        }

        let urlString =
            "https://armedia.live/search_users.php?query=\(query)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.searchResults = []
                    print("API hatası: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                }
                return
            }

            do {
                let users = try JSONDecoder().decode([Usr].self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = users
                    print("Kullanıcılar bulundu: \(users)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.searchResults = []
                    print("Kullanıcılar alınamadı: \(error)")
                }
            }
        }.resume()
    }

    func fetchRecentChats(senderId: String) {
        guard
            let url = URL(
                string:
                    "https://armedia.live/get_recent_chats.php?sender_id=\(senderId)"
            )
        else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else {
                print(
                    "Son konuşmalar: Veri alınamadı - \(error?.localizedDescription ?? "Bilinmeyen hata")"
                )
                return
            }

            // Debug: Gelen veriyi yazdır
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Son konuşmalar API yanıtı: \(jsonString)")
            }

            do {
                // PHP wrapper yapısını decode et
                struct RecentChatsResponse: Codable {
                    let success: Bool
                    let data: [Usr]
                    let count: Int
                }

                let response = try JSONDecoder().decode(RecentChatsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.recentChats = response.data
                    print("Son konuşmalar yüklendi: \(response.count) adet")
                }
            } catch {
                print("Son konuşmalar parse hatası: \(error)")

                // Fallback: Eğer wrapper yoksa doğrudan array dene
                if let users = try? JSONDecoder().decode([Usr].self, from: data) {
                    DispatchQueue.main.async {
                        self.recentChats = users
                        print("Son konuşmalar (fallback): \(users.count) adet")
                    }
                }
            }
        }.resume()
    }
}

// Sohbet listesi görünümü
struct ChatListView: View {
    @StateObject private var chatService = ChatService()
    let senderId: String
    let newsItem: NewsItem?  // Haber bilgilerini tutacak değişken

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Arama çubuğu
                TextField("Kullanıcı Ara...", text: $chatService.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: chatService.searchText) { _, newValue in
                        chatService.searchUsers(query: newValue)
                    }

                // Kullanıcı listesini göster
                List {
                    ForEach(
                        chatService.searchText.isEmpty
                            ? chatService.recentChats : chatService.searchResults
                    ) { user in
                        NavigationLink(
                            destination: ChatView(
                                senderId: senderId, receiverId: user.username, newsItem: newsItem)
                        ) {
                            HStack {
                                // Profil ikonu
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.ad_soyad)
                                        .font(.headline)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Mesajlar")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if !senderId.isEmpty {
                    print(senderId)
                    chatService.fetchRecentChats(senderId: senderId)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// Haber Önizleme Kartı
struct NewsPreviewCard: View {
    let url: String
    let isSender: Bool
    let title: String?
    let imageUrl: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Haber görseli
                if let img = imageUrl, !img.isEmpty {
                    AsyncImage(url: URL(string: img)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure(_):
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 60, height: 60)
                        case .empty:
                            ProgressView()
                                .frame(width: 60, height: 60)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 60, height: 60)
                }

                // Haber başlığı
                VStack(alignment: .leading, spacing: 4) {
                    Text(title ?? "Haber")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text("Haberi görüntüle →")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(10)
            .frame(maxWidth: 280, alignment: .leading)
            .background(isSender ? Color.blue : Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// Mesajın haber linki olup olmadığını kontrol et
func isNewsURL(_ text: String) -> Bool {
    // Debug log
    print("isNewsURL kontrolü: \(text)")

    // Haber URL'si kontrolü - armedia.live veya arhaber içeriyorsa
    let isNews =
        (text.contains("armedia.live") || text.contains("arhaber"))
        && (text.hasPrefix("http://") || text.hasPrefix("https://"))

    print("isNewsURL sonuç: \(isNews)")
    return isNews
}

// Sohbet görünümü
struct ChatView: View {
    @StateObject private var chatServiceWebSocket = ChatWebSocketService()
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatService = ChatService()
    @StateObject private var moderationManager = ContentModerationManager.shared
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    @State private var messageToReport: Message?
    @State private var reportReason = ""
    @State private var messageText = ""
    @State private var urlToOpen: URLItem?  // Açılacak URL'yi tutacak değişken
    @State private var timer: Timer?  // Timer değişkeni

    // WhatsApp-style scroll tracking
    @State private var userSentMessage = false
    @State private var isAtBottom = true
    @State private var previousMessageCount = 0

    // Keyboard tracking
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?

    let senderId: String
    let receiverId: String
    let newsItem: NewsItem?  // Haber bilgilerini tutacak değişken

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                        ForEach(
                            chatService.messages.reversed().filter {
                                !moderationManager.isBlocked($0.sender_id)
                                    && !moderationManager.containsProhibitedContent($0.text)
                            }
                        ) { message in  // Listeyi ters çeviriyoruz ve engellenenleri filtreliyoruz
                            HStack {
                                if message.sender_id == senderId {
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        // Haber bilgisi varsa kart göster
                                        if message.haber_baslik != nil {
                                            NewsPreviewCard(
                                                url: message.text,
                                                isSender: true,
                                                title: message.haber_baslik,
                                                imageUrl: message.haber_resim
                                            ) {
                                                urlToOpen = URLItem(url: message.text)
                                            }
                                        } else if let url = URL(string: message.text),
                                            UIApplication.shared.canOpenURL(url)
                                        {
                                            Button(action: {
                                                urlToOpen = URLItem(url: message.text)
                                            }) {
                                                Text(message.text)
                                                    .padding()
                                                    .background(Color.blue)
                                                    .foregroundColor(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                        } else {
                                            Text(message.text)
                                                .padding()
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }

                                        Text(message.timestamp)
                                            .font(.system(size: 7))
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    VStack(alignment: .leading) {
                                        // Haber bilgisi varsa kart göster
                                        if message.haber_baslik != nil {
                                            NewsPreviewCard(
                                                url: message.text,
                                                isSender: false,
                                                title: message.haber_baslik,
                                                imageUrl: message.haber_resim
                                            ) {
                                                urlToOpen = URLItem(url: message.text)
                                            }
                                        } else if let url = URL(string: message.text),
                                            UIApplication.shared.canOpenURL(url)
                                        {
                                            Button(action: {
                                                urlToOpen = URLItem(url: message.text)
                                            }) {
                                                Text(message.text)
                                                    .padding()
                                                    .background(Color.green)
                                                    .foregroundColor(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                        } else {
                                            Text(message.text)
                                                .padding()
                                                .background(Color.green)
                                                .foregroundColor(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        Text(message.timestamp)
                                            .font(.system(size: 7))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            }
                            .id(message.id)
                            .contextMenu {
                                if message.sender_id != senderId {
                                    Button(role: .destructive) {
                                        reportContent(message: message)
                                    } label: {
                                        Label(
                                            "Haber Ver / Raporla",
                                            systemImage: "exclamationmark.triangle")
                                    }
                                }
                            }
                        }
                    }
                    .padding()

                    // Track scroll position with GeometryReader
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    // Check if user is at bottom (within threshold)
                    isAtBottom = value > -50
                }
                .onChange(of: chatService.messages.count) { oldCount, newCount in
                    // WhatsApp-style scroll behavior
                    if newCount > previousMessageCount {
                        let shouldScroll = userSentMessage || isAtBottom
                        if shouldScroll, let lastMessage = chatService.messages.first {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                        userSentMessage = false
                        previousMessageCount = newCount
                    }
                }
                .onAppear {
                    // Store scrollView proxy for keyboard-triggered scroll
                    self.scrollProxy = scrollView

                    get_device_token(user: receiverId)
                    chatService.fetchMessages(senderId: senderId, receiverId: receiverId)
                    //chatServiceWebSocket.receiveMessage()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        //chatServiceWebSocket.connect()
                        if let lastMessage = chatService.messages.first {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        previousMessageCount = chatService.messages.count
                    }
                }
                .onDisappear {
                    // Görünüm kaybolduğunda observer'ı kaldır
                    NotificationCenter.default.removeObserver(
                        self, name: NSNotification.Name("OpenChat"), object: nil)
                    //chatServiceWebSocket.disconnect()
                }
            }

            HStack {
                TextField("Mesajınızı yazın...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
                    .onAppear {
                        // Eğer haber URL'si varsa, mesaj yazma alanına ekle
                        if let newsItem = newsItem {
                            messageText = newsItem.haber_url  // Haber URL'sini mesaj alanına ekle
                        }
                    }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            .padding()
        }
        .onAppear {
            scrollProxy = nil  // Will be set by ScrollViewReader
            chatService.fetchMessages(senderId: senderId, receiverId: receiverId)
            startTimer()  // Timer'ı başlat
        }
        .onDisappear {
            stopTimer()  // Timer'ı durdur
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect
            {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
                // Scroll to bottom when keyboard appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let lastMessage = chatService.messages.first {
                        withAnimation {
                            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .sheet(item: $urlToOpen) { item in
            WebViewContainer_Mesaj(urlString: item.url) {
                urlToOpen = nil  // Kapatma işlemi
            }
        }
        .navigationTitle(receiverId)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showBlockAlert = true }) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Kullanıcıyı Engelle", isPresented: $showBlockAlert) {
            Button("İptal", role: .cancel) {}
            Button("Engelle", role: .destructive) {
                blockUser()
            }
        } message: {
            Text(
                "\(receiverId) adlı kullanıcıyı engellemek istediğinize emin misiniz? Bu kullanıcıdan bir daha mesaj almayacaksınız ve geliştirici bilgilendirilecek."
            )
        }
        .alert("İçeriği Raporla", isPresented: $showReportAlert) {
            TextField("Şikayet nedeni...", text: $reportReason)
            Button("İptal", role: .cancel) { reportReason = "" }
            Button("Raporla", role: .destructive) {
                submitReport()
            }
        } message: {
            Text("Lütfen bu mesajı neden rapor ettiğinizi belirtin.")
        }
    }

    private func blockUser() {
        moderationManager.blockUserOnServer(blockerUsername: senderId, blockedUsername: receiverId)
        { success in
            // Locally refreshed via StateObject
        }
    }

    private func reportContent(message: Message) {
        messageToReport = message
        reportReason = ""
        showReportAlert = true
    }

    private func submitReport() {
        guard let message = messageToReport, !reportReason.isEmpty else { return }
        moderationManager.reportContent(
            type: "message",
            contentId: message.id,
            reason: reportReason,
            reporterUsername: senderId,
            reportedUsername: message.sender_id
        ) { success, msg in
            print("Reported: \(msg)")
        }
    }

    func get_device_token(user: String) {
        guard
            let url = URL(
                string: "https://armedia.live/get_device_token.php")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let postString = "user=\(user)"
        request.httpBody = postString.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("Geçersiz veri alındı")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data, options: [])
                as? [String: Any]
            {
                if let token = json["device_token"] as? String {
                    DispatchQueue.main.async {
                        self.authViewModel.deviceToken = token
                    }
                } else {
                    print("Token bulunamadı")
                }
            } else {
                print("JSON çözümleme hatası")
            }
        }
        task.resume()
    }

    func increaseShareCount(for url: String?) {
        guard let url = url else { return }

        let urlString = "https://armedia.live/paylasim_sayisi.php"
        guard let requestUrl = URL(string: urlString) else { return }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        let bodyData = "haber_url=\(url)"
        request.httpBody = bodyData.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                return
            }

            if let response = response as? HTTPURLResponse {
                print("Yanıt durumu: \(response.statusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Yanıt: \(responseString)")
            }
        }.resume()
    }

    func sendMessage() {
        // Mark that user sent a message (for WhatsApp-style scroll)
        userSentMessage = true

        // Klavyeyi kapat
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        guard !messageText.isEmpty else {
            print("Mesaj gönderilemedi: Mesaj boş.")
            userSentMessage = false
            return
        }

        let currentMessage = messageText
        messageText = ""  // Mesaj gönderildikten sonra metni temizle

        // Cihaz token'ını al ve print et
        guard let deviceToken = self.authViewModel.deviceToken else {
            print("Cihaz Token'ı bulunamadı.")
            return
        }

        print("Cihaz Token'ı: \(deviceToken)")

        chatService.sendMessage(
            senderId: senderId, receiverId: receiverId, text: currentMessage,
            deviceToken: deviceToken,
            haberBaslik: newsItem?.baslik,
            haberResim: newsItem?.originalResimUrl ?? newsItem?.resim_url
        ) { success, message in
            if success {
                DispatchQueue.main.async {
                    chatService.fetchMessages(senderId: self.senderId, receiverId: self.receiverId)
                }
                if let newsItem = newsItem {
                    increaseShareCount(for: newsItem.haber_url)
                }

            } else {
                print("Mesaj gönderilemedi: \(message)")
            }
        }
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            chatService.fetchMessages(senderId: senderId, receiverId: receiverId)  // Mesajları güncelle
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// URL'yi tutacak struct
struct URLItem: Identifiable {
    let id = UUID()  // Her URL için benzersiz bir kimlik
    let url: String
}

// WebViewContainer
struct WebViewContainer_Mesaj: UIViewRepresentable {
    let urlString: String
    let onClose: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            uiView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    class Coordinator: NSObject {
        let onClose: () -> Void

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }
    }
}
