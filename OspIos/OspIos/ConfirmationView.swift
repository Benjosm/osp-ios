import SwiftUI

struct ConfirmationView: View {
    let trustScore: Int
    let uploadTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 30) {
            // Title
            Text("Upload Confirmed")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Trust Score Display
            VStack(spacing: 10) {
                Text("Trust Score")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("\(trustScore)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(getTrustScoreColor(trustScore))
                    .frame(minWidth: 120, minHeight: 120)
                    .overlay(
                        Circle()
                            .stroke(getTrustScoreColor(trustScore), lineWidth: 4)
                    )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 4)
            
            // Upload Metrics
            VStack(alignment: .leading, spacing: 8) {
                Text("Upload Metrics")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Upload Time:")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.2f seconds", uploadTime))
                        .fontWeight(.semibold)
                }
                
                Divider()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 4)
            
            // Confirmation Button
            Button("Continue") {
                // This will be handled by the presenting view
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .font(.headline)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationBarTitle("", displayMode: .large)
        .navigationBarHidden(true)
    }
    
    // Returns color based on trust score value
    private func getTrustScoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        case 0..<40:
            return .red
        default:
            return .gray
        }
    }
}

struct ConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConfirmationView(trustScore: 85, uploadTime: 2.45)
                .preferredColorScheme(.light)
            
            ConfirmationView(trustScore: 85, uploadTime: 2.45)
                .preferredColorScheme(.dark)
        }
    }
}
