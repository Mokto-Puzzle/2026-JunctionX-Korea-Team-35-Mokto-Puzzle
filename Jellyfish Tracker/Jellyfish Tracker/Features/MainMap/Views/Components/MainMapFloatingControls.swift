import SwiftUI

struct MainMapFloatingControls: View {
    let onNearMe: () -> Void
    let onCompare: () -> Void

    var body: some View {
        HStack {
            Button(action: onNearMe) {
                Image("IconNearMe")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 21, height: 21)
                    .foregroundStyle(Color.jellyMint)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.72), in: .circle)
                    .overlay {
                        Circle().stroke(Color.jellyMint.opacity(0.25), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Near me")
            Spacer()
            Button(action: onCompare) {
                HStack(spacing: 8) {
                    Image("IconCompare")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 21, height: 21)
                    Text("Compare")
                        .font(.custom("Helvetica-Bold", size: 16, relativeTo: .callout))
                }
                .padding(.horizontal, 2)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
    }
}

#Preview("Floating Controls") {
    MainMapFloatingControls(onNearMe: {}, onCompare: {})
        .padding(.vertical, 40)
        .background(Color(red: 0.68, green: 0.91, blue: 1.0))
}
