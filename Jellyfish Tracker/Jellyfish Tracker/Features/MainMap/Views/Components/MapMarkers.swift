import SwiftUI

struct BeachPin: View {
    let beach: Beach
    let risk: RiskLevel
    let selected: Bool
    let usesMockRisk: Bool
    let showsRadius: Bool
    let temperature: String?

    var body: some View {
        VStack(spacing: -14) {
            if let temperature {
                Text(temperature)
                    .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                    .foregroundStyle(AppColor.risk(risk))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(AppColor.Fill.Button.normalRaised, in: .capsule)
                    .zIndex(2)
            }
            VStack(spacing: 2) {
                Image(pinAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(shortName)
                    .font(.custom("Helvetica", size: 14, relativeTo: .caption))
                    .foregroundStyle(AppColor.Text.normal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(width: 91, height: 91)
            .background(showsRadius ? radiusFill : .clear, in: .circle)
            .overlay {
                if selected {
                    Circle().stroke(AppColor.risk(risk).opacity(0.55), lineWidth: 2)
                }
            }
        }
        .frame(width: 91)
    }

    private var shortName: String {
        beach.displayName.replacingOccurrences(of: " Beach", with: "")
    }

    private var radiusFill: Color {
        switch risk {
        case .good: AppColor.Fill.OnMap.green
        case .caution: AppColor.Fill.OnMap.orange
        case .later: AppColor.Fill.OnMap.red
        case .unknown: AppColor.Fill.OnMap.unknown
        }
    }

    private var pinAssetName: String {
        switch risk {
        case .good: "MapPinGreen"
        case .caution: "MapPinOrange"
        case .later: "MapPinRed"
        case .unknown: "MapPinGreen"
        }
    }
}

extension Beach {
    var searchDisplayName: String {
        displayName.replacingOccurrences(of: " Beach", with: "")
    }
}

struct MainMapJellyfishMarker: View {
    let status: String?
    let mock: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let status {
                Text(status).font(.caption2.weight(.bold)).foregroundStyle(AppColor.LegacyTracker.coral)
            } else if mock {
                Text("!").font(.caption.weight(.bold)).foregroundStyle(AppColor.LegacyTracker.coral)
            }
            Image("JellyMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .padding(9)
                .background(AppColor.LegacyTracker.coral.opacity(0.88), in: .circle)
                .overlay { Circle().stroke(AppColor.LegacyTracker.coral.opacity(0.30), lineWidth: 10) }
                .shadow(color: AppColor.LegacyTracker.coral.opacity(0.24), radius: 8)
        }
    }
}

#Preview("Map Markers") {
    HStack(spacing: 24) {
        BeachPin(
            beach: MockOceanDataProvider.beaches.first { $0.id == "chilpo" } ?? MockOceanDataProvider.beaches[0],
            risk: .good,
            selected: true,
            usesMockRisk: true,
            showsRadius: true,
            temperature: "24°C"
        )
        BeachPin(
            beach: MockOceanDataProvider.beaches.first { $0.id == "yeongildae" } ?? MockOceanDataProvider.beaches[0],
            risk: .later,
            selected: false,
            usesMockRisk: true,
            showsRadius: false,
            temperature: nil
        )
        MainMapJellyfishMarker(status: nil, mock: false)
    }
    .padding()
    .background(AppColor.Preview.markerBackdrop)
}
