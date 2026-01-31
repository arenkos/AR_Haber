//
//  SubscriptionManager.swift
//  AR Haber
//
//  Created by Aren Koş on 31.01.2025.
//

import Foundation
import StoreKit

// MARK: - Subscription Types
enum SubscriptionType: String, CaseIterable {
    case adFree = "com.arhaber.subscription.adfree"
    case aiPro = "com.arhaber.subscription.ai"
    case premium = "com.arhaber.subscription.premium"

    var displayName: String {
        switch self {
        case .adFree: return "Reklamsız"
        case .aiPro: return "AI Pro"
        case .premium: return "Premium"
        }
    }

    var description: String {
        switch self {
        case .adFree: return "Tüm reklamlar kaldırılır"
        case .aiPro: return "AI Chat + Haber Özetleme"
        case .premium: return "Reklamsız + AI Pro"
        }
    }

    var icon: String {
        switch self {
        case .adFree: return "eye.slash.fill"
        case .aiPro: return "sparkles"
        case .premium: return "crown.fill"
        }
    }

    var dbValue: String {
        switch self {
        case .adFree: return "adfree"
        case .aiPro: return "ai"
        case .premium: return "premium"
        }
    }
}

// MARK: - Database Subscription Response
struct SubscriptionResponse: Codable {
    let success: Bool
    let is_active: Bool?
    let subscription_type: String?
    let expires_date: String?
    let has_ad_free: Bool?
    let has_ai_access: Bool?
    let has_premium: Bool?
    let error: String?
}

struct ReceiptValidationResponse: Codable {
    let success: Bool
    let is_active: Bool?
    let subscription_type: String?
    let expires_date: String?
    let product_id: String?
    let error: String?
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: Set<String> = []
    @Published var isLoading = false

    // Database-based subscription status
    @Published var dbSubscriptionType: String?
    @Published var dbExpiresDate: Date?
    @Published var dbHasAdFree: Bool = false
    @Published var dbHasAIAccess: Bool = false
    @Published var dbHasPremium: Bool = false

    private var updateListenerTask: Task<Void, Error>?
    private let lastCheckKey = "lastSubscriptionCheckDate"

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Check Access (Database-based)
    var hasAdFreeAccess: Bool {
        dbHasAdFree || purchasedSubscriptions.contains(SubscriptionType.adFree.rawValue)
            || purchasedSubscriptions.contains(SubscriptionType.premium.rawValue)
    }

    var hasAIAccess: Bool {
        dbHasAIAccess || purchasedSubscriptions.contains(SubscriptionType.aiPro.rawValue)
            || purchasedSubscriptions.contains(SubscriptionType.premium.rawValue)
    }

    var hasPremiumAccess: Bool {
        dbHasPremium || purchasedSubscriptions.contains(SubscriptionType.premium.rawValue)
    }

    var hasAnySubscription: Bool {
        dbSubscriptionType != nil || !purchasedSubscriptions.isEmpty
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        do {
            let productIds = SubscriptionType.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
        } catch {
            print("Ürünler yüklenemedi: \(error)")
        }
        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product, username: String) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            // Apple'dan receipt al ve sunucuya gönder
            await validateAndSaveToDatabase(username: username, productId: product.id)

            await updateSubscriptionStatus()
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases(username: String) async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()

            // Aktif abonelik varsa veritabanına kaydet
            for productId in purchasedSubscriptions {
                await validateAndSaveToDatabase(username: username, productId: productId)
            }
        } catch {
            print("Satın almalar geri yüklenemedi: \(error)")
        }
    }

    // MARK: - Update Status
    func updateSubscriptionStatus() async {
        var activeSubscriptions: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    activeSubscriptions.insert(transaction.productID)
                }
            } catch {
                print("Transaction doğrulanamadı: \(error)")
            }
        }

        purchasedSubscriptions = activeSubscriptions
    }

    // MARK: - Validate Receipt and Save to Database
    func validateAndSaveToDatabase(username: String, productId: String) async {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
            FileManager.default.fileExists(atPath: appStoreReceiptURL.path)
        else {
            print("Receipt bulunamadı")
            return
        }

        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL)
            let receiptString = receiptData.base64EncodedString()

            guard let url = URL(string: "https://armedia.live/validate_receipt.php") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "receipt_data": receiptString,
                "username": username,
                "product_id": productId,
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)

            if let response = try? JSONDecoder().decode(ReceiptValidationResponse.self, from: data)
            {
                if response.success && response.is_active == true {
                    print(
                        "Abonelik veritabanına kaydedildi: \(response.subscription_type ?? "unknown")"
                    )

                    // Local state güncelle
                    self.dbSubscriptionType = response.subscription_type
                    updateAccessFlags(subscriptionType: response.subscription_type)

                    if let expiresStr = response.expires_date {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        self.dbExpiresDate = formatter.date(from: expiresStr)
                    }
                } else {
                    print("Receipt validation hatası: \(response.error ?? "Bilinmeyen hata")")
                }
            }
        } catch {
            print("Receipt gönderme hatası: \(error)")
        }
    }

    // MARK: - Check Subscription from Database
    func checkSubscriptionFromDatabase(username: String) async {
        guard
            let url = URL(
                string: "https://armedia.live/check_subscription.php?username=\(username)")
        else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let response = try? JSONDecoder().decode(SubscriptionResponse.self, from: data) {
                if response.success {
                    self.dbSubscriptionType = response.subscription_type
                    self.dbHasAdFree = response.has_ad_free ?? false
                    self.dbHasAIAccess = response.has_ai_access ?? false
                    self.dbHasPremium = response.has_premium ?? false

                    if let expiresStr = response.expires_date {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        self.dbExpiresDate = formatter.date(from: expiresStr)
                    }

                    print("Veritabanından abonelik durumu: \(response.subscription_type ?? "yok")")
                }
            }
        } catch {
            print("Veritabanından abonelik kontrolü hatası: \(error)")
        }
    }

    // MARK: - Daily Subscription Check
    func performDailyCheck(username: String) async {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        let now = Date()

        // Son 24 saatte kontrol yapıldı mı?
        if let lastCheck = lastCheck {
            let hoursSinceLastCheck =
                Calendar.current.dateComponents([.hour], from: lastCheck, to: now).hour ?? 0
            if hoursSinceLastCheck < 24 {
                print("Son 24 saatte kontrol yapıldı, atlanıyor")
                return
            }
        }

        print("Günlük abonelik kontrolü yapılıyor...")

        // 1. Veritabanından kontrol et
        await checkSubscriptionFromDatabase(username: username)

        // 2. Apple'dan kontrol et ve senkronize et
        await updateSubscriptionStatus()

        // 3. Apple'da aktif abonelik varsa veritabanını güncelle
        for productId in purchasedSubscriptions {
            await validateAndSaveToDatabase(username: username, productId: productId)
        }

        // Son kontrol tarihini kaydet
        UserDefaults.standard.set(now, forKey: lastCheckKey)

        print("Günlük kontrol tamamlandı")
    }

    // MARK: - Helper: Update Access Flags
    private func updateAccessFlags(subscriptionType: String?) {
        guard let type = subscriptionType else {
            dbHasAdFree = false
            dbHasAIAccess = false
            dbHasPremium = false
            return
        }

        switch type {
        case "adfree":
            dbHasAdFree = true
            dbHasAIAccess = false
            dbHasPremium = false
        case "ai":
            dbHasAdFree = false
            dbHasAIAccess = true
            dbHasPremium = false
        case "premium":
            dbHasAdFree = true
            dbHasAIAccess = true
            dbHasPremium = true
        default:
            dbHasAdFree = false
            dbHasAIAccess = false
            dbHasPremium = false
        }
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction güncellemesi başarısız: \(error)")
                }
            }
        }
    }

    // MARK: - Verify Transaction
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Store Error
enum StoreError: Error {
    case failedVerification
}
