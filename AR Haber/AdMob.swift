//
//  AdConstants.swift
//  AR Haber
//
//  Created by Aren Koş on 7.02.2025.
//

import AppTrackingTransparency
import Combine
import GoogleMobileAds
import SwiftUI
import WebKit

// MARK: - Reklam Sabitleri
struct AdConstants {
    static let appID = "ca-app-pub-6912090056166853~3231299076"

    // Test reklamları için
    static let testBannerID = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialID = "ca-app-pub-3940256099942544/4411468910"

    // Gerçek reklamlar için
    static let bannerAdUnitID = "ca-app-pub-6912090056166853/1324652236"  // Haberler arasında (Banner)
    static let nativeAdUnitID = "ca-app-pub-6912090056166853/1918217405"  // Native (kullanılmıyor şimdilik)
    static let interstitialAdUnitID = "ca-app-pub-6912090056166853/1471487316"  // Sayfa geçişleri

    static let requestDelay: TimeInterval = 10.0

    static var currentBannerID: String {
        return bannerAdUnitID
    }

    static var currentInterstitialID: String {
        return interstitialAdUnitID
    }
}

// MARK: - Smart Ad Banner (Abonelik Kontrolü ile)
struct SmartAdBannerView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        if !subscriptionManager.hasAdFreeAccess {
            AdBannerView()
        }
        // Abone ise reklam gösterilmez
    }
}

// MARK: - Banner Reklam View (Haberler Arasında)
struct AdBannerView: UIViewRepresentable {
    let adUnitID = AdConstants.currentBannerID

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let bannerView = BannerView()
        bannerView.adSize = AdSizeMediumRectangle
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first?.rootViewController
        {
            bannerView.rootViewController = rootViewController
        }

        containerView.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        // Reklam yükle
        print("📢 Banner reklam yükleniyor, adUnitID: \(adUnitID)")
        loadAdWithATTCheck(bannerView: bannerView)

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Banner reklam yüklendi")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Banner reklam yüklenemedi: \(error.localizedDescription)")
        }
    }
}

// MARK: - ATT Kontrolü ile Reklam Yükleme
private func loadAdWithATTCheck(bannerView: BannerView, attempt: Int = 0) {
    if #available(iOS 14, *) {
        let status = ATTrackingManager.trackingAuthorizationStatus
        print("📢 ATT durumu: \(status.rawValue)")
        if status == .notDetermined {
            if attempt < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    loadAdWithATTCheck(bannerView: bannerView, attempt: attempt + 1)
                }
            } else {
                let request = Request()
                bannerView.load(request)
            }
            return
        }
    }

    let request = Request()
    bannerView.load(request)
}
