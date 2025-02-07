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
                    Label("Genel Akış", systemImage: "house.fill")
                }

            if authViewModel.isLoggedIn {
                Kaynak()
                    .tabItem {
                        Label("Kaynak", systemImage: "newspaper.fill")
                    }
                
                Kategori()
                    .tabItem {
                        Label("Kategori", systemImage: "square.grid.2x2.fill")
                    }
                
                Ozel_Akis()
                    .tabItem {
                        Label("Özel Akış", systemImage: "star.fill")
                    }
            }

            Profil()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
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
