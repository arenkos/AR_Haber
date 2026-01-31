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
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

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

                    // Terms
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
                await subscriptionManager.restorePurchases()
                if subscriptionManager.hasAnySubscription {
                    dismiss()
                }
            }
        }
        .font(.footnote)
        .foregroundColor(.blue)
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Abonelik, seçilen süre sonunda otomatik olarak yenilenir.")
            Text("İstediğiniz zaman Ayarlar'dan iptal edebilirsiniz.")
        }
        .font(.caption)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
    }

    // MARK: - Purchase Action
    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        do {
            let success = try await subscriptionManager.purchase(product)
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
