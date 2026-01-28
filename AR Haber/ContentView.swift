import SwiftUI
import SwiftUI
import WebKit
import Combine
import GoogleMobileAds


struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedUserId: String? = nil
    @State private var selectedTab: Int = 0
    @State private var showAIChat: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
        TabView(selection: $selectedTab) {
            Genel_Akis()
                .tabItem {
                    Label("Ana sayfa", systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                }
                .tag(0)

            if authViewModel.isLoggedIn {
                Kaynak()
                    .tabItem {
                        Label("Kaynak", systemImage: "newspaper.fill")
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                    }
                    .tag(1)
                
                Kategori()
                    .tabItem {
                        Label("Kategori", systemImage: "square.grid.2x2.fill")
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                    }
                    .tag(2)
                
                Ozel_Akis()
                    .tabItem {
                        Label("Özel", systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                    }
                    .tag(3)

                /*if let user = authViewModel.user {
                    ChatListView(senderId: user.username, receiverId: selectedUserId)
                        .tabItem {
                            Label("Mesaj", systemImage: "bubble.fill")
                                .frame(maxWidth: .infinity)
                                .layoutPriority(1)
                        }
                        .tag(4)
                }*/
            }

            Profil()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                }
                .tag(5)
        }
        .accentColor(.blue)
        .onAppear {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenChat"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo, let userId = userInfo["userId"] as? String {
                    self.selectedUserId = userId
                    self.selectedTab = 5 // Mesaj sekmesine yönlendir
                    let control = Control()
                    control.notification = true
                }
            }
        }
        
        // Ortada yuvarlak AI Chat butonu
        VStack {
            Spacer()
            
            Button(action: {
                showAIChat = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard)
        }
        .sheet(isPresented: $showAIChat) {
            AIChatView()
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let urlString: String
    let onClose: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            print("📱 Loading URL: \(url.absoluteString)")
            uiView.load(URLRequest(url: url))
        } else {
            print("❌ Invalid URL: \(urlString)")
        }
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onClose: () -> Void
        
        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Page loaded successfully: \(webView.url?.absoluteString ?? "Unknown")")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ Navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ Provisional navigation failed: \(error.localizedDescription)")
            print("   URL: \(webView.url?.absoluteString ?? "Unknown")")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Search", text: $text)
            .padding(7)
            .padding(.horizontal, 20)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                    Spacer()
                }
            )
            .padding(.horizontal)
    }
}


struct Contentview_Previews: PreviewProvider {
    static var previews: some View {
       ContentView()
    }
}

// MARK: - AI Chat View

struct AIChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var typingTimer: Timer?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mesaj listesi
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages.indices, id: \.self) { index in
                                ChatBubble(message: $messages[index])
                                    .id(messages[index].id)
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("AI düşünüyor...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input alanı
                HStack(spacing: 12) {
                    TextField("Mesajınızı yazın...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI Asistan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear {
            if messages.isEmpty {
                var welcomeMessage = ChatMessage(
                    content: "Merhaba! Ben AI asistanınızım. Size nasıl yardımcı olabilirim?",
                    isUser: false
                )
                welcomeMessage.displayedContent = ""
                messages.append(welcomeMessage)
                startTypewriterEffect(for: 0)
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        var userMessage = ChatMessage(content: inputText, isUser: true)
        userMessage.displayedContent = inputText
        messages.append(userMessage)
        
        let messageToSend = inputText
        inputText = ""
        isLoading = true
        
        // OpenAI servisini kullan
        OpenAIService().sendChatMessage(text: messageToSend) { response in
            isLoading = false
            if let response = response {
                var aiMessage = ChatMessage(content: response, isUser: false)
                aiMessage.displayedContent = ""
                aiMessage.isTyping = true
                messages.append(aiMessage)
                
                let messageIndex = messages.count - 1
                startTypewriterEffect(for: messageIndex)
            } else {
                var errorMessage = ChatMessage(
                    content: "Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin.",
                    isUser: false
                )
                errorMessage.displayedContent = errorMessage.content
                messages.append(errorMessage)
            }
        }
    }
    
    private func startTypewriterEffect(for index: Int) {
        guard index < messages.count else { return }
        
        let fullContent = messages[index].content
        let characters = Array(fullContent)
        var charIndex = 0
        
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if charIndex < characters.count {
                messages[index].displayedContent.append(characters[charIndex])
                charIndex += 1
            } else {
                messages[index].isTyping = false
                timer.invalidate()
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
    var displayedContent: String = ""
    var isTyping: Bool = false
}

struct ChatBubble: View {
    @Binding var message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(message.displayedContent.isEmpty ? message.content : message.displayedContent)
                        .padding(12)
                        .background(message.isUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(16)
                    
                    // Typing cursor efekti
                    if !message.isUser && message.isTyping {
                        Text("▌")
                            .foregroundColor(.gray)
                            .font(.system(size: 16, weight: .bold))
                            .animation(
                                Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                value: message.isTyping
                            )
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}

