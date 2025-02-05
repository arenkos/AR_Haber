import SwiftUI
import GoogleMobileAds

@main
struct ARHaberApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // AdMob'u başlat
        MobileAds.shared.start { status in
            print("AdMob initialization status: \(status)")
            
            // Test cihazı ayarlarını başlatma tamamlandıktan sonra yap
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
                "c0cfc390665976fe28ee5f7f48d859f9",  // Sizin cihazınızın test kimliği
                "GADSimulatorID"                      // Simulator için
            ]
        }
        return true
    }
} 