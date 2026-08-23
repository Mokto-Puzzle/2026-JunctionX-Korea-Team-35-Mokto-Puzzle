import CoreLocation
import SwiftUI

struct NearbyComparisonView: View {
    @ObservedObject var model: JellyMapViewModel
    let userCoordinate: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss

    private var nearbyBeaches: [Beach] {
        model.nearby(to: userCoordinate, count: 4)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppColor.Fill.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .ignoresSafeArea(edges: .top)
                beachList
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppColor.Text.normal)
                        .frame(width: 40, height: 40)
                        .background(AppColor.Fill.Button.normalMedium, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close comparison")

                Text("Compare Nearby Beaches")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColor.Text.white)
            }
            .padding(.top, 77)

            Spacer()
                .frame(height: 12)

            HStack(spacing: 4) {
                Image("IconNearMe")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text("77, Cheongam-ro, Nam-gu, Pohang-si")
                    .font(.system(size: 14, weight: .regular))
            }
            .foregroundStyle(AppColor.Text.white)
            .padding(.bottom, 12)

            Text("Beaches nearby you")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(AppColor.Text.white)
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 231, maxHeight: 231, alignment: .topLeading)
        .background(AppColor.Fill.Button.accent)
        .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
    }

    private var beachList: some View {
        VStack(spacing: 16) {
            ForEach(nearbyBeaches) { beach in
                ComparisonBeachCard(
                    beach: beach,
                    risk: model.risk(for: beach),
                    summary: summary(for: beach),
                    onDisclosureTap: {
                        model.focus(on: beach)
                        dismiss()
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func summary(for beach: Beach) -> String {
        let hour = Int(model.forecastHour.rounded())
        let wavePhrase = beach.marine.waveHeight <= 1.2 ? "calm" : "active"
        let waveText = String(format: "%.1f m", beach.marine.waveHeight)
        if hour < 0 {
            let sightings = beach.recentJellyfish ? "recent sightings reported" : "no recent sightings reported"
            return "\(abs(hour))h ago reference: \(sightings), with \(wavePhrase) waves (\(waveText))."
        }
        let timeText = hour == 0 ? "Now" : "+\(hour)h forecast"
        return "\(timeText): modeled jellyfish impact \(model.markedImpact(for: beach)), with \(wavePhrase) waves (\(waveText))."
    }
}

private struct ComparisonBeachCard: View {
    let beach: Beach
    let risk: RiskLevel
    let summary: String
    let onDisclosureTap: () -> Void

    var body: some View {
        Button(action: onDisclosureTap) {
            HStack(spacing: 16) {
                jellyfishIcon

                VStack(alignment: .leading, spacing: 6) {
                    Text(beach.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.Text.normal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(summary)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image("IconChevronRight")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(AppColor.Icon.secondary)
                    .frame(width: 32, height: 44)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(beach.displayName) detail")
        .padding(.leading, 14)
        .padding(.trailing, 9)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .center)
        .background(cardFill, in: .rect(cornerRadius: 16))
    }

    private var jellyfishIcon: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 55, height: 55)
    }

    private var assetName: String {
        switch risk {
        case .good, .unknown:
            "JellyfishGood"
        case .caution:
            "JellyfishCaution"
        case .later:
            "JellyfishHigh"
        }
    }

    private var cardFill: Color {
        switch risk {
        case .good, .unknown:
            AppColor.Fill.Comparison.goodCard
        case .caution:
            AppColor.Fill.Comparison.cautionCard
        case .later:
            AppColor.Fill.Comparison.highCard
        }
    }

}

#Preview("Nearby Comparison") {
    NearbyComparisonView(
        model: JellyMapViewModel(provider: MockOceanDataProvider()),
        userCoordinate: LocationManager.fallback
    )
}
