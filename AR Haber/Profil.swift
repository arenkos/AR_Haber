//
//  AuthView.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//


import SwiftUI
import CommonCrypto
import WebKit
import Combine
import GoogleMobileAds

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var user: User? = nil
    @Published var errorMessage: String = ""
    static let shared = AuthViewModel() // Singleton

    @Published var deviceToken: String? {
        didSet {
            if let token = deviceToken {
                UserDefaults.standard.set(token, forKey: "deviceToken")
            }
        }
    }

    init() {
        loadUserSession()
        self.deviceToken = UserDefaults.standard.string(forKey: "deviceToken")
    }

    func setDeviceToken(_ token: String) {
        DispatchQueue.main.async {
            self.deviceToken = token
            print("✅ AuthViewModel içinde token güncellendi: \(token)")
        }
    }
    
    func sha256(_ string: String) -> String {
        if let data = string.data(using: .utf8) {
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            _ = data.withUnsafeBytes {
                CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return ""
    }
    
    func login(username: String, password: String) {
        guard let url = URL(string: "https://armedya.aryazilimdanismanlik.com/login.php") else {
            self.errorMessage = "Geçersiz URL"
            return
        }
        let hashedpassword = sha256(password)
        let parameters: [String: String] = [
            "username": username,
            "password": hashedpassword
        ]
        
        guard let postData = try? JSONSerialization.data(withJSONObject: parameters) else {
            self.errorMessage = "Veri formatı hatalı"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Bağlantı hatası: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self.errorMessage = "Yanıt alınamadı"
                    return
                }

                // Sunucudan gelen cevabı ekrana yazdır (debug için)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Sunucu Yanıtı: \(jsonString)")
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let status = json["status"] as? String, status == "success" {
                            let email = json["mail"] as? String ?? ""
                            let ad_soyad = json["ad_soyad"] as? String ?? ""
                            let telefon = json["telefon"] as? String ?? ""
                            let username = json["username"] as? String ?? ""
                            
                            let loggedInUser = User(email: email, telefon: telefon, username: username, ad_soyad: ad_soyad)
                            
                            self.user = loggedInUser
                            self.isLoggedIn = true
                            self.errorMessage = ""
                            
                            // Kullanıcı oturumunu kaydet
                            self.saveUserSession(user: loggedInUser)
                        } else {
                            self.errorMessage = json["message"] as? String ?? "Giriş başarısız"
                        }
                    } else {
                        self.errorMessage = "Yanıt formatı hatalı"
                    }
                } catch {
                    self.errorMessage = "JSON çözme hatası: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func kayit(username: String, ad_soyad: String, telefon: String, email: String, password: String) {
        guard let url = URL(string: "https://armedya.aryazilimdanismanlik.com/kayit.php") else {
            self.errorMessage = "Geçersiz URL"
            self.showAlert(message: self.errorMessage) // self kullanıldı
            return
        }
        let hashedpassword = sha256(password)
        let parameters: [String: String] = [
            "username": username,
            "password": hashedpassword,
            "ad_soyad": ad_soyad,
            "mail": email,
            "telefon": telefon
        ]

        guard let postData = try? JSONSerialization.data(withJSONObject: parameters) else {
            self.errorMessage = "Veri formatı hatalı"
            self.showAlert(message: self.errorMessage) // self kullanıldı
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Geçersiz yanıt"
                        self.showAlert(message: self.errorMessage) // self kullanıldı
                    }
                    return
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let status = json["status"] as? String {
                        DispatchQueue.main.async {
                            switch status {
                            case "success":
                                self.errorMessage = "Kayıt Başarılı"
                                self.showAlert(message: self.errorMessage) // self kullanıldı
                            case "exist":
                                self.errorMessage = "Bu bilgilerle kayıtlı kullanıcı zaten var!"
                                self.showAlert(message: self.errorMessage) // self kullanıldı
                            default:
                                self.errorMessage = json["message"] as? String ?? "Bilinmeyen hata oluştu"
                                self.showAlert(message: self.errorMessage) // self kullanıldı
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Bağlantı hatası: \(error.localizedDescription)"
                    self.showAlert(message: self.errorMessage) // self kullanıldı
                }
            }
        }
    }

    // Alert gösteren fonksiyon
    func showAlert(message: String) {
        let alertController = UIAlertController(title: "Bilgi", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Tamam", style: .default, handler: nil)
        alertController.addAction(okAction)
        // Eğer bu fonksiyonu bir ViewController içinde çağırıyorsanız
        if let viewController = UIApplication.shared.windows.first?.rootViewController {
            viewController.present(alertController, animated: true, completion: nil)
        }
    }

    func logout() {
        self.isLoggedIn = false
        self.user = nil
        
        clearUserSession()
    }
    
    private func saveUserSession(user: User) {
            UserDefaults.standard.setValue(user.email, forKey: "email")
            UserDefaults.standard.setValue(user.telefon, forKey: "telefon")
            UserDefaults.standard.setValue(user.username, forKey: "username")
            UserDefaults.standard.setValue(user.ad_soyad, forKey: "ad_soyad")
            UserDefaults.standard.setValue(true, forKey: "isLoggedIn")
        }

        private func loadUserSession() {
            let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            if isLoggedIn {
                let user = User(
                    email: UserDefaults.standard.string(forKey: "email") ?? "",
                    telefon: UserDefaults.standard.string(forKey: "telefon") ?? "",
                    username: UserDefaults.standard.string(forKey: "username") ?? "",
                    ad_soyad: UserDefaults.standard.string(forKey: "ad_soyad") ?? ""
                )
                self.user = user
                self.isLoggedIn = true
            }
        }

        private func clearUserSession() {
            UserDefaults.standard.removeObject(forKey: "email")
            UserDefaults.standard.removeObject(forKey: "telefon")
            UserDefaults.standard.removeObject(forKey: "username")
            UserDefaults.standard.removeObject(forKey: "ad_soyad")
            UserDefaults.standard.setValue(false, forKey: "isLoggedIn")
        }
}

struct User{
    let email: String
    let telefon: String
    let username: String
    let ad_soyad: String
}

class Control: ObservableObject {
    @Published var notification = false
}

struct Profil: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var control: Control
    @State private var isLogin = true
    @State private var ad_soyad = ""
    @State private var username = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var selectedUserId: String? = nil
    @State private var isChatActive: Bool = false
    private var usr: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if authViewModel.isLoggedIn, let user = authViewModel.user {
                    Text("Profil Bilgileri")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)

                    HStack {
                        NavigationLink(destination: AccountSettingsView()) {
                            VStack {
                                Image(systemName: "gear")
                                    .font(.largeTitle)
                                    .padding()
                                Text("Hesap Ayarları")
                                    .font(.subheadline)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(10)
                        }

                        NavigationLink(destination: LikesView()) {
                            VStack {
                                Image(systemName: "star.fill")
                                    .font(.largeTitle)
                                    .padding()
                                Text("Beğenilenler")
                                    .font(.subheadline)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    HStack {
                        NavigationLink(destination: ChatListView(senderId: user.username, newsItem: nil)) {
                            VStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.largeTitle)
                                    .padding()
                                Text("Mesajlar")
                                    .font(.subheadline)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(10)
                        }

                        /*NavigationLink(destination: OtherFeatureView()) {
                            VStack {
                                Image(systemName: "ellipsis.circle")
                                    .font(.largeTitle)
                                    .padding()
                                Text("Diğer Özellikler")
                                    .font(.subheadline)
                            }
                            .frame(width: 150, height: 150)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(10)
                        }*/
                    }
                    .padding(.horizontal)

                    Button(action: { authViewModel.logout() }) {
                        Text("Çıkış Yap")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                } else {
                    // Giriş yapmamış kullanıcı için kayıt/giriş formu
                    VStack(spacing: 20) {
                        Text(isLogin ? "Giriş Yap" : "Kayıt Ol")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 40)

                        if !isLogin {
                            TextField("Ad Soyad", text: $ad_soyad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }

                        TextField("Kullanıcı Adı", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .autocapitalization(.none)
                            .onChange(of: username) { newValue in
                                username = newValue.lowercased().replacingOccurrences(of: " ", with: "")
                            }

                        SecureField("Şifre", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        if !isLogin {
                            SecureField("Şifre Tekrar", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }

                        Button(action: handleAuth) {
                            Text(isLogin ? "Giriş Yap" : "Kayıt Ol")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }

                        Button(action: { isLogin.toggle() }) {
                            Text(isLogin ? "Hesabın yok mu? Kayıt ol" : "Zaten hesabın var mı? Giriş yap")
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .padding()
        }
        .onAppear(){
            NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenChat"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo, let userId = userInfo["userId"] as? String {
                    self.selectedUserId = userId
                    self.isChatActive = true // Mesajlaşma sayfasına yönlendirme yapılıyor
                }
            }
        }
    }
    
    func handleAuth() {
        errorMessage = ""
        
        if username.isEmpty || password.isEmpty {
            errorMessage = "Kullanıcı adı ve şifre gereklidir."
            return
        }
        
        if !isLogin && password != confirmPassword {
            errorMessage = "Şifreler uyuşmuyor."
            return
        }
        
        if isLogin{
            authViewModel.login(username: username, password: password)
        } else {
            //authViewModel.kayit(username: username, email: email, password: password, ad_soyad: ad_soyad)
            authViewModel.kayit(username: username, ad_soyad: ad_soyad, telefon: telefon, email: email, password: password)
        }
    }
} 

struct Profil_Previews: PreviewProvider {
    static var previews: some View {
        Profil()
    }
}

struct OtherFeatureView: View {
    var body: some View {
        Text("Diğer Özellikler Sayfası")
    }
}
