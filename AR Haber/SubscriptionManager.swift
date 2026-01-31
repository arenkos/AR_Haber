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
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: Set<String> = []
    @Published var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

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

    // MARK: - Check Access
    var hasAdFreeAccess: Bool {
        purchasedSubscriptions.contains(SubscriptionType.adFree.rawValue)
            || purchasedSubscriptions.contains(SubscriptionType.premium.rawValue)
    }

    var hasAIAccess: Bool {
        purchasedSubscriptions.contains(SubscriptionType.aiPro.rawValue)
            || purchasedSubscriptions.contains(SubscriptionType.premium.rawValue)
    }

    var hasPremiumAccess: Bool {
        purchasedSubscriptions.contains(SubscriptionType.premium.rawValue)
    }

    var hasAnySubscription: Bool {
        !purchasedSubscriptions.isEmpty
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
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
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
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
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
