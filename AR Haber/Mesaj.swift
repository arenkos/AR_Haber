import SwiftUI
import Foundation

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
                    print("Mesajlar alındı: \(messages)") // Hata ayıklama için
                }
            } catch {
                print("Mesajlar alınamadı: \(error)")
            }
        }.resume()
    }
    
    func sendMessage(senderId: String, receiverId: String, text: String) {
        guard let url = URL(string: "https://www.aryazilimdanismanlik.com/armedya/send_message.php") else { return }
        
        let body: [String: Any] = [
            "sender_id": senderId,
            "receiver_id": receiverId,
            "text": text
        ]
        
        
        let jsonData = try? JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Mesaj gönderme hatası: \(error.localizedDescription)")
                return
            }
            
            // API'den gelen yanıtı kontrol et
            if let httpResponse = response as? HTTPURLResponse {
                print("Mesaj gönderme yanıtı: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("Mesaj başarıyla gönderildi.")
                } else {
                    // Hata mesajını kontrol et
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Mesaj gönderilemedi, durum kodu: \(httpResponse.statusCode), Yanıt: \(responseString)")
                    } else {
                        print("Mesaj gönderilemedi, durum kodu: \(httpResponse.statusCode)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.fetchMessages(senderId: senderId, receiverId: receiverId)
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
    
    var body: some View {
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
                        chatService.selectedReceiver = user
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
        .sheet(item: $chatService.selectedReceiver) { user in
            ChatView(senderId: senderId, receiverId: user.username)
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
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    
    let senderId: String
    let receiverId: String
    
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(chatService.messages) { message in
                        HStack {
                            if message.sender_id == senderId {
                                Spacer()
                                VStack{
                                    Text(message.text)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(message.timestamp)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .font(.system(size: 7)) // Adjust the font size as needed
                                }
                            } else {
                                VStack{
                                    Text(message.text)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(message.timestamp)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .font(.system(size: 7)) // Adjust the font size as needed
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Mesajınızı yazın...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 8)
                
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
        }
    }
    
    func sendMessage() {
        // Klavyeyi kapat
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        guard !messageText.isEmpty else {
            print("Mesaj gönderilemedi: Mesaj boş.")
            return
        }
        
        // Mesaj gönderme işlemi sırasında butonu devre dışı bırak
        let currentMessage = messageText
        messageText = "" // Mesaj gönderildikten sonra metni temizle
        chatService.sendMessage(senderId: senderId, receiverId: receiverId, text: currentMessage)
    }
}
