import SwiftUI

extension Color {
    static let jellyMint = Color(red: 0, green: 0.80, blue: 0.69)
    static let jellyInk = Color(red: 0.08, green: 0.12, blue: 0.11)
    static let jellyCaption = Color(red: 0.45, green: 0.55, blue: 0.53)
    static let jellyCoral = Color(red: 1.0, green: 0.32, blue: 0.26)

    static let ocean = trackerCyan
    static let seafoam = Color(red: 0.22, green: 0.84, blue: 0.68)
    static let cautionOrange = Color(red: 1.0, green: 0.62, blue: 0.16)
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
