import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "flower_orders/live_activity",
                binaryMessenger: controller.binaryMessenger
            )
            channel.setMethodCallHandler(FlowerLiveActivityCoordinator.handle)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
