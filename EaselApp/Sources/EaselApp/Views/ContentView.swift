import SwiftUI
#if canImport(ARKit)
import ARKit
#endif

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authService: AuthenticationService
    @State private var isARSupported: Bool = {
        #if canImport(ARKit)
        return ARWorldTrackingConfiguration.isSupported
        #else
        return false
        #endif
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "arkit")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to Easel")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI-Powered AR Home Design")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "camera.viewfinder",
                        title: "Room Scanning",
                        description: "Scan rooms with ARKit precision"
                    )
                    
                    FeatureRow(
                        icon: "wand.and.rays",
                        title: "AI Design Generation",
                        description: "Generate designs from natural language"
                    )
                    
                    FeatureRow(
                        icon: "cube.transparent",
                        title: "3D Visualization",
                        description: "Visualize designs in augmented reality"
                    )
                    
                    FeatureRow(
                        icon: "doc.text",
                        title: "Export & Share",
                        description: "Export designs as PDFs or 3D models"
                    )
                }
                
                Spacer()
                
                VStack(spacing: 15) {
                    if isARSupported {
                        NavigationLink(destination: ARScanningView()) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start New Project")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        NavigationLink(destination: ProjectListView()) {
                            HStack {
                                Image(systemName: "folder.fill")
                                Text("My Projects")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    } else {
                        VStack {
                            Text("AR Not Supported")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("This device doesn't support ARKit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
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
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        List {
            ForEach(dataManager.projects) { project in
                NavigationLink(destination: ProjectDetailView(project: project)) {
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        Text("Modified: \(project.modifiedDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("My Projects")
    }
}

struct ProjectDetailView: View {
    let project: Project
    
    var body: some View {
        VStack {
            Text("Project: \(project.name)")
                .font(.title)
            
            Text("Created: \(project.createdDate, style: .date)")
                .font(.caption)
            
            Spacer()
            
            Text("Project details will be implemented here")
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle(project.name)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager.shared)
        .environmentObject(AuthenticationService.shared)
}