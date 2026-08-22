import SwiftUI

extension Color {
    static let brandTeal = AppColor.Fill.Button.accent
}

struct JellyfishGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let headBottom = rect.minY + rect.height * 0.58

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: headBottom))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.10, y: headBottom),
            control1: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.12),
            control2: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.10, y: headBottom),
            control1: CGPoint(x: centerX + rect.width * 0.18, y: rect.minY + rect.height * 0.72),
            control2: CGPoint(x: centerX - rect.width * 0.18, y: rect.minY + rect.height * 0.72)
        )
        path.closeSubpath()

        for index in 0..<3 {
            let x = rect.minX + rect.width * (0.28 + Double(index) * 0.22)
            path.move(to: CGPoint(x: x, y: headBottom - 1))
            path.addCurve(
                to: CGPoint(x: x - rect.width * 0.10, y: rect.maxY - rect.height * 0.05),
                control1: CGPoint(x: x + rect.width * 0.09, y: rect.minY + rect.height * 0.72),
                control2: CGPoint(x: x - rect.width * 0.12, y: rect.minY + rect.height * 0.84)
            )
            path.addLine(to: CGPoint(x: x - rect.width * 0.16, y: rect.maxY - rect.height * 0.10))
            path.addCurve(
                to: CGPoint(x: x - rect.width * 0.045, y: headBottom - 1),
                control1: CGPoint(x: x - rect.width * 0.05, y: rect.minY + rect.height * 0.82),
                control2: CGPoint(x: x - rect.width * 0.02, y: rect.minY + rect.height * 0.70)
            )
            path.closeSubpath()
        }
        return path
    }
}
