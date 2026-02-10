//
//  AIConsentManager.swift
//  AR Haber
//
//  Created by Antigravity AI on 11.02.2026.
//

import SwiftUI

/// Manages user consent for AI data sharing with OpenAI
class AIConsentManager: ObservableObject {
    static let shared = AIConsentManager()

    private let consentKey = "aiDataConsent"

    @Published var hasUserConsented: Bool {
        didSet {
            UserDefaults.standard.set(hasUserConsented, forKey: consentKey)
        }
    }

    init() {
        self.hasUserConsented = UserDefaults.standard.bool(forKey: consentKey)
    }

    func grantConsent() {
        hasUserConsented = true
    }

    func revokeConsent() {
        hasUserConsented = false
    }
}

/// A view modifier that shows AI consent alert before proceeding
struct AIConsentAlertModifier: ViewModifier {
    @ObservedObject var consentManager = AIConsentManager.shared
    @Binding var showConsentAlert: Bool
    var onConsent: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Yapay Zeka Veri Paylaşımı", isPresented: $showConsentAlert) {
                Button("Kabul Ediyorum", role: nil) {
                    consentManager.grantConsent()
                    onConsent()
                }
                Button("Reddet", role: .cancel) {
                    // Do nothing - user denied
                }
            } message: {
                Text(
                    """
                    Bu özellik, mesajlarınızı ve haber içeriklerini yapay zeka hizmetleri (OpenAI) ile paylaşmaktadır.

                    Paylaşılan Veriler:
                    • Yazdığınız mesaj metinleri
                    • Haber URL'leri ve içerikleri

                    Veri Gönderilen Hizmet:
                    • OpenAI (ABD merkezli yapay zeka şirketi)

                    Kişisel bilgileriniz (ad, e-posta vb.) bu hizmetle paylaşılmaz. Detaylı bilgi için Gizlilik Politikamızı inceleyebilirsiniz.
                    """)
            }
    }
}

extension View {
    func aiConsentAlert(isPresented: Binding<Bool>, onConsent: @escaping () -> Void) -> some View {
        modifier(AIConsentAlertModifier(showConsentAlert: isPresented, onConsent: onConsent))
    }
}
