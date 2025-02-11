import UserNotifications
import SwiftUI
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @EnvironmentObject var authViewModel: AuthViewModel
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // AdMob'u başlat
        MobileAds.shared.start { status in
            print("AdMob initialization status: \(status)")
        }
        
        // Push bildirimlerini kaydet
        registerForPushNotifications(application: application)
        
        return true
    }
    
    // APNs kayıt işlemi
    func registerForPushNotifications(application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Bildirim izni hatası: \(error.localizedDescription)")
                return
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("Kullanıcı bildirim iznini reddetti.")
            }
        }
    }
    
    // Cihaz başarılı şekilde APNs token aldı
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ Cihaz Token'ı alındı: \(tokenString)")

        DispatchQueue.main.async {
            AuthViewModel.shared.setDeviceToken(tokenString) // DOĞRU ✅
        }
    }
    
    // APNs token alma işlemi başarısız olursa
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs kayıt hatası: \(error.localizedDescription)")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let userId = userInfo["user_id"] as? String {
            NotificationCenter.default.post(name: NSNotification.Name("OpenChat"), object: nil, userInfo: ["userId": userId])
        }

        completionHandler()
    }
    
    // Bildirim alındığında çalışır (Foreground durumda)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 Bildirim alındı: \(notification.request.content.userInfo)")
        completionHandler([.banner, .sound])
    }
}
