import SwiftUI
import ARKit
import RealityKit
import FirebaseCore

@main
struct EaselApp: App {
    
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Easel")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("AI-Powered AR Home Design")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
                
                VStack(spacing: 20) {
                    NavigationLink("Start New Project") {
                        ARScanningView()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    NavigationLink("My Projects") {
                        ProjectListView()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .navigationTitle("Easel")
            .navigationBarHidden(true)
        }
    }
}

// Placeholder views for navigation
struct ARScanningView: View {
    var body: some View {
        Text("AR Scanning View")
            .navigationTitle("Scan Room")
    }
}

struct ProjectListView: View {
    var body: some View {
        Text("Project List View")
            .navigationTitle("My Projects")
    }
}

#Preview {
    ContentView()
}