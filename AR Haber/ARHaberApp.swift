import SwiftUI
import GoogleMobileAds
import BackgroundTasks

@main
struct ARHaberApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
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
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourapp.backgroundTask", using: nil) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }

    func handleBackgroundTask(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform your background processing here
        
        task.setTaskCompleted(success: true)
    }
}
