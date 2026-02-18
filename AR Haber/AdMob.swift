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

// AdConstants'ı güncelleyelim
struct AdConstants {
    static let appID = "ca-app-pub-6912090056166853~3231299076"

    // Test reklamları için
    static let testBannerID = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialID = "ca-app-pub-3940256099942544/4411468910"

    // Gerçek reklamlar için
    static let nativeAdUnitID = "ca-app-pub-6912090056166853/1918217405"  // Haberler arasında (Native)
    static let interstitialAdUnitID = "ca-app-pub-6912090056166853/1471487316"  // Sayfa geçişleri

    static let requestDelay: TimeInterval = 10.0

    // Kullanılacak reklam kimliklerini seç
    /*static var currentBannerID: String {
        #if DEBUG
        return testBannerID
        #else
        return bannerAdUnitID
        #endif
    }
    
    static var currentInterstitialID: String {
        #if DEBUG
        return testInterstitialID
        #else
        return interstitialAdUnitID
        #endif
    }*/

    static var currentNativeID: String {
        return nativeAdUnitID
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

// AdBannerView'ı güncelleyelim
struct AdBannerView: UIViewRepresentable {
    let adUnitID = AdConstants.currentNativeID

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let screenWidth = UIScreen.main.bounds.width  // Ekran genişliğini al
        containerView.frame = CGRect(origin: .zero, size: CGSize(width: screenWidth, height: 200))  // Ekran genişliğini kullan

        let bannerView = BannerView()
        bannerView.adSize = AdSizeBanner
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first?.rootViewController
        {
            bannerView.rootViewController = rootViewController
        }

        containerView.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        // Kenarlarda boşluk bırakmak için 20 birim boşluk ekleyelim
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            bannerView.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: -40),  // 20 birim sağdan ve soldan boşluk
            bannerView.heightAnchor.constraint(equalToConstant: 200),
        ])

        // Reklam yükle
        loadAdWithATTCheck(bannerView: bannerView)

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("Banner reklam yüklendi")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner reklam yüklenemedi: \(error.localizedDescription)")
        }
    }
}

// GADBannerViewController'ı güncelleyelim
struct GADBannerViewController: UIViewControllerRepresentable {
    let adUnitID = AdConstants.currentNativeID

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.frame = CGRect(origin: .zero, size: CGSize(width: 320, height: 50))

        let bannerView = BannerView()
        bannerView.adSize = AdSizeBanner
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = viewController
        bannerView.delegate = context.coordinator

        viewController.view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: 320),
            bannerView.heightAnchor.constraint(equalToConstant: 50),
        ])

        // Reklam yüklemeyi geciktir
        loadAdWithATTCheck(bannerView: bannerView)

        return viewController
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("Banner reklam yüklendi")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner reklam yüklenemedi: \(error.localizedDescription)")
        }
    }
}

// Helper to check ATT and load ad
private func loadAdWithATTCheck(bannerView: BannerView, attempt: Int = 0) {
    // iOS 14+ control
    if #available(iOS 14, *) {
        let status = ATTrackingManager.trackingAuthorizationStatus
        if status == .notDetermined {
            // Henüz izin verilmedi veya reddedilmedi, biraz bekle ve tekrar dene
            if attempt < 10 {  // Max 10 deneme (yaklaşık 10-20 sn)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    loadAdWithATTCheck(bannerView: bannerView, attempt: attempt + 1)
                }
            } else {
                // Zaman aşımı, yine de yükle (reklamsız veya varsayılan)
                let request = Request()
                bannerView.load(request)
            }
            return
        }
    }

    // İzin durumu belli (authorized, denied, restricted) veya iOS < 14
    let request = Request()
    bannerView.load(request)
}
