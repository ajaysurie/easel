import SwiftUI
import ARKit

struct ContentView: View {
    @State private var isARSupported = ARWorldTrackingConfiguration.isSupported
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
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
                
                // Features
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
                
                // Action Button
                VStack(spacing: 15) {
                    if isARSupported {
                        Button(action: {
                            // TODO: Navigate to scanning view
                        }) {
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
            .navigationBarHidden(true)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}