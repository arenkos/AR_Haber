//
//  PaywallView.swift
//  AR Haber
//
//  Created by Aren Koş on 31.01.2025.
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLoginRequired = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Products
                    if subscriptionManager.isLoading {
                        ProgressView("Yükleniyor...")
                            .padding()
                    } else if subscriptionManager.products.isEmpty {
                        Text("Abonelik paketleri yüklenemedi")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        productsSection
                    }

                    // Purchase Button
                    purchaseButton

                    // Restore Button
                    restoreButton

                    // Terms and Links
                    termsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Premium'a Geç")
                .font(.title)
                .fontWeight(.bold)

            Text("AI özellikleri ve reklamsız deneyimin keyfini çıkarın")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Products Section
    private var productsSection: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionManager.products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    subscriptionType: SubscriptionType(rawValue: product.id)
                ) {
                    selectedProduct = product
                }
            }
        }
    }

    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button(action: {
            Task {
                await purchase()
            }
        }) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Abone Ol")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: selectedProduct != nil ? [.blue, .purple] : [.gray, .gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(selectedProduct == nil || isPurchasing)
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button("Satın Almaları Geri Yükle") {
            Task {
                if let username = authViewModel.user?.username {
                    await subscriptionManager.restorePurchases(username: username)
                    if subscriptionManager.hasAnySubscription {
                        dismiss()
                    }
                }
            }
        }
        .font(.footnote)
        .foregroundColor(.blue)
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 12) {
            Text("Premium Abonelik (Auto-Renewing)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(
                "Aboneliğiniz seçilen süre sonunda (aylık vb.) otomatik olarak yenilenir. Yenileme tarihinden 24 saat önce iptal etmediğiniz takdirde ücret hesabınızdan tahsil edilecektir. Aboneliğinizi cihazınızın App Store Ayarlarından yönetebilir ve iptal edebilirsiniz."
            )
            .font(.caption2)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button(action: {
                    if let url = URL(string: "https://armedia.live/kullanici.php") {
                        openURL(url)
                    }
                }) {
                    Text("Kullanım Koşulları (EULA)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }

                Button(action: {
                    if let url = URL(string: "https://armedia.live/gizlilik.php") {
                        openURL(url)
                    }
                }) {
                    Text("Gizlilik Politikası")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Purchase Action
    private func purchase() async {
        guard let product = selectedProduct else { return }

        // Giriş kontrolü
        guard let username = authViewModel.user?.username else {
            showLoginRequired = true
            return
        }

        isPurchasing = true
        do {
            let success = try await subscriptionManager.purchase(product, username: username)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = "Satın alma başarısız: \(error.localizedDescription)"
            showError = true
        }
        isPurchasing = false
    }
}

extension PaywallView {
    // LoginRequired alert modifier
    func withLoginAlert() -> some View {
        self.alert("Giriş Gerekli", isPresented: .constant(false)) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Abonelik satın almak için lütfen giriş yapın.")
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let subscriptionType: SubscriptionType?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: subscriptionType?.icon ?? "star.fill")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    .cornerRadius(10)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionType?.displayName ?? product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subscriptionType?.description ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("/ay")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
}
