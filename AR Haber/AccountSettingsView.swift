//
//  AccountSettingsView.swift
//  AR Haber
//
//  Created by Aren Koş on 11.02.2025.
//

import SwiftUI

// WebView için item struct
struct WebViewItem: Identifiable {
    let id = UUID()
    let url: String
    let title: String
}

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var webViewItem: WebViewItem? = nil
    @State private var showDeleteAlert = false
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var deleteError = ""

    var body: some View {
        List {
            if let user = authViewModel.user {
                // MARK: - Profil Bilgileri
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.ad_soyad)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Hesap Bilgileri
                Section(header: Text("Hesap Bilgileri")) {
                    SettingsRowView(icon: "person.fill", title: "Ad Soyad", value: user.ad_soyad)
                    SettingsRowView(icon: "at", title: "Kullanıcı Adı", value: user.username)
                    SettingsRowView(
                        icon: "envelope.fill", title: "E-posta",
                        value: user.email.isEmpty ? "Belirtilmemiş" : user.email)
                    SettingsRowView(
                        icon: "phone.fill", title: "Telefon",
                        value: user.telefon.isEmpty ? "Belirtilmemiş" : user.telefon)
                }

                // MARK: - Abonelik
                Section(header: Text("Abonelik")) {
                    NavigationLink(destination: PaywallView()) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Premium Üyelik Yönetimi")
                                .foregroundColor(.primary)
                        }
                    }
                }

                // MARK: - Şifre Değiştir
                Section(header: Text("Şifre Değiştir")) {
                    SecureField("Yeni Şifre", text: $newPassword)
                    SecureField("Şifre Tekrar", text: $confirmPassword)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Button(action: updateProfile) {
                        HStack {
                            Spacer()
                            Image(systemName: "key.fill")
                            Text("Şifreyi Güncelle")
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                }

                // MARK: - Hakkında
                Section(header: Text("Hakkında")) {
                    Button(action: {
                        webViewItem = WebViewItem(
                            url: "https://armedia.live/gizlilik.php",
                            title: "Gizlilik Politikası"
                        )
                    }) {
                        SettingsLinkRowView(
                            icon: "lock.shield.fill", title: "Gizlilik Politikası", color: .green)
                    }

                    Button(action: {
                        webViewItem = WebViewItem(
                            url: "https://armedia.live/hakkimizda.php",
                            title: "Hakkımızda"
                        )
                    }) {
                        SettingsLinkRowView(
                            icon: "info.circle.fill", title: "Hakkımızda", color: .blue)
                    }

                    Button(action: {
                        webViewItem = WebViewItem(
                            url: "https://armedia.live/iletisim.php",
                            title: "İletişim"
                        )
                    }) {
                        SettingsLinkRowView(
                            icon: "envelope.circle.fill", title: "İletişim", color: .orange)
                    }
                }

                // MARK: - Uygulama Bilgisi
                Section(header: Text("Uygulama")) {
                    HStack {
                        Text("Versiyon")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }

                // MARK: - Çıkış Yap
                Section {
                    Button(action: { authViewModel.logout() }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Çıkış Yap")
                                .foregroundColor(.red)
                        }
                    }
                }

                // MARK: - Hesabı Sil
                Section {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Hesabımı Sil")
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }

                    if !deleteError.isEmpty {
                        Text(deleteError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Hesap Yönetimi")
                } footer: {
                    Text(
                        "Hesabınızı sildiğinizde tüm verileriniz kalıcı olarak silinir ve bu işlem geri alınamaz."
                    )
                    .font(.caption2)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $webViewItem) { item in
            NavigationView {
                WebViewContainer(
                    urlString: item.url,
                    onClose: {
                        webViewItem = nil
                    }, hideHeader: true
                )
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Kapat") {
                            webViewItem = nil
                        }
                    }
                }
            }
        }
        // MARK: - Delete Account First Alert
        .alert("Hesabınızı Silmek İstediğinize Emin Misiniz?", isPresented: $showDeleteAlert) {
            Button("Evet, Silmek İstiyorum", role: .destructive) {
                showDeleteConfirmation = true
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text(
                "Bu işlem geri alınamaz. Tüm verileriniz (yorumlar, mesajlar, tercihler) kalıcı olarak silinecektir."
            )
        }
        // MARK: - Delete Account Confirmation
        .alert("Son Onay", isPresented: $showDeleteConfirmation) {
            TextField("SİL yazın", text: $deleteConfirmText)
            Button("Hesabımı Kalıcı Olarak Sil", role: .destructive) {
                if deleteConfirmText == "SİL" {
                    deleteAccount()
                } else {
                    deleteError = "Onay metni hatalı. Lütfen 'SİL' yazın."
                }
                deleteConfirmText = ""
            }
            Button("İptal", role: .cancel) {
                deleteConfirmText = ""
            }
        } message: {
            Text("Onaylamak için aşağıya büyük harflerle 'SİL' yazın.")
        }
    }

    func updateProfile() {
        errorMessage = ""
        successMessage = ""

        if newPassword.isEmpty || confirmPassword.isEmpty {
            errorMessage = "Yeni şifre ve onay şifresi gereklidir."
            return
        }

        if newPassword != confirmPassword {
            errorMessage = "Şifreler uyuşmuyor."
            return
        }

        if newPassword.count < 6 {
            errorMessage = "Şifre en az 6 karakter olmalıdır."
            return
        }

        guard let user = authViewModel.user else { return }
        let parameters: [String: String] = [
            "username": user.username,
            "new_password": authViewModel.sha256(newPassword),
        ]

        guard let url = URL(string: "https://armedia.live/profil_guncelle.php")
        else {
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

                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Sunucu Yanıtı: \(jsonString)")
                    successMessage = "Şifreniz başarıyla güncellendi!"
                    newPassword = ""
                    confirmPassword = ""
                }
            }
        }.resume()
    }

    func deleteAccount() {
        guard let user = authViewModel.user else {
            deleteError = "Kullanıcı bilgisi bulunamadı"
            return
        }

        isDeleting = true
        deleteError = ""

        authViewModel.deleteAccount(username: user.username) { success, message in
            isDeleting = false
            if !success {
                deleteError = message ?? "Hesap silinemedi. Lütfen tekrar deneyin."
            }
            // On success, AuthViewModel handles logout and cleanup
        }
    }
}

// MARK: - Yardımcı View'lar
struct SettingsRowView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }
}

struct SettingsLinkRowView: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct AccountSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountSettingsView()
            .environmentObject(AuthViewModel())  // Örnek bir AuthViewModel ekleyin
    }
}
