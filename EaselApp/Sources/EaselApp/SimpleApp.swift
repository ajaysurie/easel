import SwiftUI

@main
struct SimpleEaselApp: App {
    var body: some Scene {
        WindowGroup {
            SimpleContentView()
        }
    }
}

struct SimpleContentView: View {
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
                    SimpleFeatureRow(
                        icon: "camera.viewfinder",
                        title: "Room Scanning",
                        description: "Scan rooms with ARKit precision"
                    )
                    
                    SimpleFeatureRow(
                        icon: "wand.and.rays",
                        title: "AI Design Generation",
                        description: "Generate designs from natural language"
                    )
                    
                    SimpleFeatureRow(
                        icon: "cube.transparent",
                        title: "3D Visualization",
                        description: "Visualize designs in augmented reality"
                    )
                    
                    SimpleFeatureRow(
                        icon: "doc.text",
                        title: "Export & Share",
                        description: "Export designs as PDFs or 3D models"
                    )
                }
                
                Spacer()
                
                VStack(spacing: 15) {
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
                    
                    Button(action: {
                        // TODO: Navigate to projects view
                    }) {
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
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct SimpleFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    SimpleContentView()
}