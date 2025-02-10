//
//  AccountSettingsView.swift
//  AR Haber
//
//  Created by Aren Koş on 11.02.2025.
//


import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            if let user = authViewModel.user {
                Text("Hesap Ayarları")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)

                // Kullanıcı bilgilerini göster
                Text("Ad Soyad: \(user.ad_soyad)")
                Text("Kullanıcı Adı: \(user.username)")
                Text("E-posta: \(user.email)")
                Text("Telefon: \(user.telefon)")

                // Yeni şifre alanları
                SecureField("Yeni Şifre", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                SecureField("Şifre Tekrar", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Button(action: updateProfile) {
                    Text("Bilgileri Güncelle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
        .padding()
    }

    func updateProfile() {
        errorMessage = ""

        // Şifrelerin doğruluğunu kontrol et
        if newPassword.isEmpty || confirmPassword.isEmpty {
            errorMessage = "Yeni şifre ve onay şifresi gereklidir."
            return
        }

        if newPassword != confirmPassword {
            errorMessage = "Şifreler uyuşmuyor."
            return
        }

        // Kullanıcı adı ve şifre bilgilerini gönder
        guard let user = authViewModel.user else { return }
        let parameters: [String: String] = [
            "username": user.username,
            "new_password": newPassword
        ]

        guard let url = URL(string: "https://armedya.aryazilimdanismanlik.com/profil_guncelle.php") else {
            errorMessage = "Geçersiz URL"
            return
        }

        guard let postData = try? JSONSerialization.data(withJSONObject: parameters) else {
            errorMessage = "Veri formatı hatalı"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Bağlantı hatası: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    errorMessage = "Yanıt alınamadı"
                    return
                }

                // Sunucudan gelen cevabı kontrol et
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Sunucu Yanıtı: \(jsonString)")
                }

                // Başka bir JSON yanıtı kontrolü yapabilirsiniz
                // Örneğin, başarılı bir güncelleme mesajı dönebilir
            }
        }.resume()
    }
}

struct AccountSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountSettingsView()
            .environmentObject(AuthViewModel()) // Örnek bir AuthViewModel ekleyin
    }
}