import SwiftUI
import WebKit
import Combine
import GoogleMobileAds


struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            Genel_Akis()
                .tabItem {
                    Label("Ana sayfa", systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                }

            if authViewModel.isLoggedIn {
                Kaynak()
                    .tabItem {
                        Label("Kaynak", systemImage: "newspaper.fill")
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                    }
                
                Kategori()
                    .tabItem {
                        Label("Kategori", systemImage: "square.grid.2x2.fill")
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                    }
                
                Ozel_Akis()
                    .tabItem {
                        Label("Özel", systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                    }
                
                if let user = authViewModel.user {
                    ChatListView(senderId: user.username)
                        .tabItem {
                            Label("Mesaj", systemImage: "bubble.fill")
                                .frame(maxWidth: .infinity)
                                .layoutPriority(1)
                        }
                }
            }

            Profil()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                }
        }
        .accentColor(.blue)
    }
}

struct WebViewContainer: UIViewRepresentable {
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
