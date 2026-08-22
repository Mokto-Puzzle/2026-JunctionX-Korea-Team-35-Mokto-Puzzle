import SwiftUI

extension Color {
    static let jellyMint = AppColor.Fill.Button.accent
    static let jellyInk = AppColor.Text.normal
    static let jellyCaption = AppColor.Text.caption
    static let jellyCoral = AppColor.LegacyTracker.coral

    static let ocean = AppColor.LegacyTracker.cyan
    static let seafoam = AppColor.LegacyTracker.seafoam
    static let cautionOrange = AppColor.Risk.caution
    static let warmSun = AppColor.LegacyTracker.cream

    static func risk(_ risk: RiskLevel) -> Color {
        AppColor.risk(risk)
    }
}

extension View {
    func trackerPanel(cornerRadius: CGFloat = 14) -> some View {
        background(AppColor.LegacyTracker.panel.opacity(0.96), in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColor.LegacyTracker.cyan.opacity(0.9), lineWidth: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(cornerRadius - 3, 0))
                    .stroke(AppColor.LegacyTracker.cream.opacity(0.28), lineWidth: 1)
                    .padding(4)
            }
            .shadow(color: AppColor.LegacyTracker.navy.opacity(0.55), radius: 12, y: 6)
    }
}
