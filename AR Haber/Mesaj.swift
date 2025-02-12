import SwiftUI
import Foundation
import WebKit

// Mesaj yapısı
struct Message: Identifiable, Codable {
    let id: Int
    let sender_id: String
    let receiver_id: String
    let text: String
    let timestamp: String
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

// Sohbet servisi
class ChatService: ObservableObject {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Published var messages: [Message] = []
    @Published var searchResults: [Usr] = []
    @Published var recentChats: [Usr] = []
    @Published var selectedReceiver: Usr?
    @Published var searchText: String = ""

    func fetchMessages(senderId: String, receiverId: String) {
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/get_messages.php?sender_id=\(senderId)&receiver_id=\(receiverId)") else { return }
        
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
    
    func sendMessage(senderId: String, receiverId: String, text: String, deviceToken: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/send_message.php") else {
            completion(false, "URL Hatası")
            return
        }
        
        let body: [String: Any] = [
            "sender_id": senderId,
            "receiver_id": receiverId,
            "text": text,
            "device_token": deviceToken
        ]
        
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
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        // PHP'den gelen yanıtı al
                        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let status = jsonResponse["status"] as? String,
                           let message = jsonResponse["message"] as? String {
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

        let urlString = "https://www.aryazilimdanismanlik.com/armedya/search_users.php?query=\(query)"
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
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/get_recent_chats.php?sender_id=\(senderId)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let users = try? JSONDecoder().decode([Usr].self, from: data) {
                DispatchQueue.main.async {
                    self.recentChats = users
                    print("Son konuşmalar: \(users)") // Hata ayıklama için
                }
            } else {
                print("Son konuşmalar alınamadı.")
            }
        }.resume()
    }
}

// Sohbet listesi görünümü
struct ChatListView: View {
    @StateObject private var chatService = ChatService()
    let senderId: String
    let newsItem: NewsItem? // Haber bilgilerini tutacak değişken
    @State private var selectedUser: Usr? // Seçilen kullanıcıyı tutacak değişken

    var body: some View {
        Text("Mesajlar Sayfası")
        VStack {
            // Arama çubuğu
            TextField("Kullanıcı Ara...", text: $chatService.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: chatService.searchText) { newValue in
                    chatService.searchUsers(query: newValue)
                }
            
            // Kullanıcı listesini göster
            List {
                ForEach(chatService.searchText.isEmpty ? chatService.recentChats : chatService.searchResults) { user in
                    Button(action: {
                        // Seçilen kullanıcıyı ayarla
                        selectedUser = user
                    }) {
                        HStack {
                            Text(user.ad_soyad + "(" + user.username + ")")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                print("Arama sonuçları: \(chatService.searchResults)") // Hata ayıklama için
                print("Son konuşmalar: \(chatService.recentChats)") // Hata ayıklama için
            }
        }
        .sheet(item: $selectedUser) { user in
            // Kullanıcı seçildiğinde ChatView'i aç
            ChatView(senderId: senderId, receiverId: user.username, newsItem: newsItem) // Burada haber bilgilerini geçiyoruz
        }
        .onAppear {
            if !senderId.isEmpty {
                print(senderId)
                chatService.fetchRecentChats(senderId: senderId)
            }
        }
    }
}

// Sohbet görünümü
struct ChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    @State private var urlToOpen: URLItem? // Açılacak URL'yi tutacak değişken
    @State private var timer: Timer? // Timer değişkeni

    let senderId: String
    let receiverId: String
    let newsItem: NewsItem? // Haber bilgilerini tutacak değişken
    
    var body: some View {
        VStack {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                        ForEach(chatService.messages.reversed()) { message in // Listeyi ters çeviriyoruz
                            HStack {
                                if message.sender_id == senderId {
                                    Spacer()
                                    VStack {
                                        if let url = URL(string: message.text), UIApplication.shared.canOpenURL(url) {
                                            Button(action: {
                                                urlToOpen = URLItem(url: message.text)
                                            }) {
                                                Text(message.text)
                                                    .padding()
                                                    .background(Color.blue)
                                                    .foregroundColor(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                            }
                                        } else {
                                            Text(message.text)
                                                .padding()
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        
                                        Text(message.timestamp)
                                            .font(.system(size: 7))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                } else {
                                    VStack {
                                        if let url = URL(string: message.text), UIApplication.shared.canOpenURL(url) {
                                            Button(action: {
                                                urlToOpen = URLItem(url: message.text)
                                            }) {
                                                Text(message.text)
                                                    .padding()
                                                    .background(Color.green)
                                                    .foregroundColor(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        } else {
                                            Text(message.text)
                                                .padding()
                                                .background(Color.green)
                                                .foregroundColor(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Text(message.timestamp)
                                            .font(.system(size: 7))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    get_device_token(user: receiverId)
                    chatService.fetchMessages(senderId: senderId, receiverId: receiverId)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let lastMessage = chatService.messages.first {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onDisappear {
                    // Görünüm kaybolduğunda observer'ı kaldır
                    NotificationCenter.default.removeObserver(self, name: NSNotification.Name("OpenChat"), object: nil)
                }
            }

            HStack {
                TextField("Mesajınızı yazın...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
                    .onAppear {
                        // Eğer haber URL'si varsa, mesaj yazma alanına ekle
                        if let newsItem = newsItem {
                            messageText = newsItem.haber_url // Haber URL'sini mesaj alanına ekle
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
            chatService.fetchMessages(senderId: senderId, receiverId: receiverId)
            startTimer() // Timer'ı başlat
        }
        .onDisappear {
            stopTimer() // Timer'ı durdur
        }
        .sheet(item: $urlToOpen) { item in
            WebViewContainer_Mesaj(urlString: item.url) {
                urlToOpen = nil // Kapatma işlemi
            }
        }
    }
    func get_device_token(user: String) {
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/get_device_token.php") else { return }

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

            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
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
        
        let urlString = "https://www.aryazilimdanismanlik.com/armedya/paylasim_sayisi.php"
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
        // Klavyeyi kapat
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        guard !messageText.isEmpty else {
            print("Mesaj gönderilemedi: Mesaj boş.")
            return
        }
        
        let currentMessage = messageText
        messageText = "" // Mesaj gönderildikten sonra metni temizle

        // Cihaz token'ını al ve print et
        guard let deviceToken = self.authViewModel.deviceToken else {
            print("Cihaz Token'ı bulunamadı.")
            return
        }

        print("Cihaz Token'ı: \(deviceToken)")
        
        chatService.sendMessage(senderId: senderId, receiverId: receiverId, text: currentMessage, deviceToken: deviceToken) { success, message in
            if success {
                DispatchQueue.main.async {
                    chatService.fetchMessages(senderId: self.senderId, receiverId: self.receiverId)
                }
            } else {
                print("Mesaj gönderilemedi: \(message)")
            }
        }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            chatService.fetchMessages(senderId: senderId, receiverId: receiverId) // Mesajları güncelle
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// URL'yi tutacak struct
struct URLItem: Identifiable {
    let id = UUID() // Her URL için benzersiz bir kimlik
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
