import SwiftUI

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
    VStack {
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
    }
}