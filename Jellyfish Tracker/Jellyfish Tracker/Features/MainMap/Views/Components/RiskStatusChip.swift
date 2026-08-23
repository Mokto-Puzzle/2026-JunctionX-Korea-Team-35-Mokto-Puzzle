import SwiftUI

struct RiskStatusChip: View {
    let risk: RiskLevel
    var height: CGFloat = 34
    var iconSize: CGFloat = 18
    var fontSize: CGFloat = 14
    var horizontalPadding: CGFloat = 12

    var body: some View {
        HStack(spacing: 6) {
            Image("IconJellyfish")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            Text(label)
                .font(.custom("Helvetica", size: fontSize, relativeTo: .caption))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)
        .background(background, in: .capsule)
    }

    private var label: String {
        switch risk {
        case .good:
            "SAFE"
        case .caution:
            "CAUTION"
        case .later:
            "DANGER"
        case .unknown:
            "CHECK"
        }
    }

    private var foreground: Color {
        switch risk {
        case .good:
            AppColor.Risk.good
        case .caution:
            AppColor.Risk.caution
        case .later:
            AppColor.Risk.high
        case .unknown:
            AppColor.Risk.unknown
        }
    }

    private var background: Color {
        switch risk {
        case .good:
            AppColor.Primitive.Green.shade100.opacity(0.72)
        case .caution:
            AppColor.Primitive.Orange.shade100.opacity(0.74)
        case .later:
            AppColor.Primitive.Red.shade100.opacity(0.74)
        case .unknown:
            AppColor.Primitive.Common.shade100.opacity(0.78)
        }
    }
}

#Preview("Risk Status Chips") {
    VStack(spacing: 18) {
        RiskStatusChip(risk: .good)
        RiskStatusChip(risk: .caution)
        RiskStatusChip(risk: .later)
    }
    .padding()
    .background(AppColor.Preview.markerBackdrop)
}
