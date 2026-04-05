import AppTrackingTransparency
import BackgroundTasks
import GoogleMobileAds
import SwiftUI
import UserNotifications

@main
struct ARHaberApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("AppLanguage") var appLanguage: String = ""

    var currentLocale: Locale {
        if appLanguage.isEmpty {
            return Locale.current
        } else {
            return Locale(identifier: appLanguage)
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environment(\.locale, currentLocale)
                .environmentObject(authViewModel)
                .onAppear {
                    registerForPushNotifications()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        requestTrackingPermission()
                    }
                }
        }
    }
}

func registerForPushNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
        granted, error in
        if let error = error {
            print("İzin hatası: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

func requestTrackingPermission() {
    // iOS 14+ için ATT izni iste
    if #available(iOS 14, *) {
        // Delay kaldırıldı, scenePhase içinde çağrılacak
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                print("Tracking izni verildi")
            case .denied:
                print("Tracking izni reddedildi")
            case .notDetermined:
                print("Tracking izni beklendi")
            case .restricted:
                print("Tracking kısıtlı")
            @unknown default:
                print("Bilinmeyen tracking durumu")
            }
        }
    }
}
