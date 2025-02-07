//
//  AuthView.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//


import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var user: User? = nil
    @Published var errorMessage: String = ""

    init() {
        loadUserSession()
    }
    
    func login(username: String, password: String) {
        guard let url = URL(string: "https://armedya.aryazilimdanismanlik.com/login.php") else {
            self.errorMessage = "Geçersiz URL"
            return
        }
        
        let parameters: [String: String] = [
            "username": username,
            "password": password
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
        print(username, ad_soyad, telefon, email, password)
        let parameters: [String: String] = [
            "username": username,
            "password": password,
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

struct User {
    let email: String
    let telefon: String
    let username: String
    let ad_soyad: String
}

struct Profil: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLogin = true
    @State private var ad_soyad = ""
    @State private var username = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    
    var body: some View {
        if authViewModel.isLoggedIn, let user = authViewModel.user {
            VStack(spacing: 20) {
                Text("Profil Bilgileri")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                Text("Ad Soyad: \(user.ad_soyad)")
                Text("Kullanıcı Adı: \(user.username)")
                Text("E-posta: \(user.email)")
                Text("Telefon: \(user.telefon)")
                
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
            }
        } else {
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
                        // Büyük harfleri küçük harfe çevir ve boşlukları kaldır
                        username = newValue.lowercased().replacingOccurrences(of: " ", with: "")
                    }
                
                if !isLogin {
                    TextField("E-posta", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .onChange(of: email) { newValue in
                            // Büyük harfleri küçük harfe çevir ve boşlukları kaldır
                            email = newValue.lowercased().replacingOccurrences(of: " ", with: "")
                        }
                    
                    TextField("Telefon", text: $telefon)
                        .keyboardType(.numberPad) // Sadece sayısal girişe izin verir
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: telefon) { newValue in
                            // Sadece rakamları kabul et
                            let filtered = newValue.filter { $0.isNumber }
                            
                            // İlk rakamın sıfır olmamasını sağla
                            if let firstChar = filtered.first, firstChar == "0" {
                                telefon = String(filtered.dropFirst()) // İlk sıfırı sil
                            } else {
                                telefon = filtered
                            }
                        }
                }
                
                HStack {
                    if showPassword {
                        TextField("Şifre", text: $password)
                    } else {
                        SecureField("Şifre", text: $password)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                
                if !isLogin {
                    HStack {
                        if showPassword {
                            TextField("Şifre Tekrar", text: $confirmPassword)
                        } else {
                            SecureField("Şifre Tekrar", text: $confirmPassword)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                    }
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
