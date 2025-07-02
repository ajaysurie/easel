import SwiftUI
import ARKit
import RealityKit
import FirebaseCore
import AVFoundation

@main
struct EaselApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var authService = AuthenticationService.shared
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Check ARKit availability
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("ARKit is not supported on this device")
        }
        
        // Check for required AR features
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("Warning: Scene reconstruction not supported - fallback mode enabled")
        }
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(authService)
                .onAppear {
                    requestCameraPermission()
                }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                print("Camera permission denied - AR features unavailable")
            }
        }
    }
}

