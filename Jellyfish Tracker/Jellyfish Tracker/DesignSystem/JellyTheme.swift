import SwiftUI

extension Color {
    static let jellyMint = AppColor.Fill.Button.accent
    static let jellyInk = AppColor.Text.normal
    static let jellyCaption = AppColor.Text.caption
    static let jellyCoral = AppColor.Primitive.Red.shade400

    static let ocean = trackerCyan
    static let seafoam = Color(red: 0.22, green: 0.84, blue: 0.68)
    static let cautionOrange = AppColor.Primitive.Orange.shade500
    static let warmSun = trackerCream

    static func risk(_ risk: RiskLevel) -> Color {
        switch risk {
        case .good: .seafoam
        case .caution: .cautionOrange
        case .later: .trackerCoral
        case .unknown: .gray
        }
    }
}

extension View {
    func trackerPanel(cornerRadius: CGFloat = 14) -> some View {
        background(Color.trackerPanel.opacity(0.96), in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.trackerCyan.opacity(0.9), lineWidth: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(cornerRadius - 3, 0))
                    .stroke(Color.trackerCream.opacity(0.28), lineWidth: 1)
                    .padding(4)
            }
            .shadow(color: Color.trackerNavy.opacity(0.55), radius: 12, y: 6)
    }
}
