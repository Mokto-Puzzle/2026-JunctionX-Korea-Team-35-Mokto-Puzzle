import SwiftUI

struct MainMapRecommendationHeader: View {
    let beachName: String
    @Binding var forecastHour: Double
    let onFilterTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Image("JellyMark")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 18, alignment: .leading)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(Date.now.formatted(.dateTime.month(.wide).day().year()))
                        .font(.custom("Helvetica", size: 14, relativeTo: .callout))
                        .foregroundStyle(AppColor.Text.caption)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(beachName)
                                .foregroundStyle(AppColor.Text.accent)
                            Text("is your")
                                .foregroundStyle(AppColor.Text.normal)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        Text("safest choice today!")
                            .foregroundStyle(AppColor.Text.normal)
                    }
                    .font(.custom("Helvetica-Bold", size: 24, relativeTo: .title2))
                    .lineSpacing(0)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                FilterCircleButton(action: onFilterTap)
            }

            TimelineSlider(value: $forecastHour)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 304, maxHeight: 304, alignment: .bottomLeading)
        .background {
            AppColor.Fill.Button.normal
                .background(.ultraThinMaterial)
                .blur(radius: 20)
        }
        .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
        .shadow(color: AppColor.Text.accent.opacity(0.08), radius: 16, y: 8)
    }
}

struct FilterCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("IconFilter")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(AppColor.Icon.accent)
                .frame(width: 38, height: 38)
                .background(AppColor.Fill.Button.normalSoft, in: .circle)
                .overlay {
                    Circle().stroke(AppColor.Fill.Button.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ocean layers")
    }
}

struct TimelineSlider: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text("-24h")
                .frame(width: 40, alignment: .leading)
                .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                .foregroundStyle(AppColor.Text.caption)
            Slider(value: Binding(
                get: { value },
                set: { newValue in
                    let snappedValue = Self.snappedForecastHour(newValue)
                    guard snappedValue != value else { return }
                    value = snappedValue
                }
            ), in: -24...24, step: 2)
                .tint(AppColor.Text.accent)
                .accessibilityLabel("Jellyfish timeline")
            Text("+24h")
                .frame(width: 40, alignment: .trailing)
                .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                .foregroundStyle(AppColor.Text.caption)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(AppColor.Fill.Button.normalMedium, in: .capsule)
    }

    private static func snappedForecastHour(_ value: Double) -> Double {
        min(max((value / 2).rounded() * 2, -24), 24)
    }
}

#Preview("Recommendation Header") {
    @Previewable @State var hour = 0.0
    MainMapRecommendationHeader(
        beachName: "Chilpo Beach",
        forecastHour: $hour,
        onFilterTap: {}
    )
    .frame(width: 402, height: 304, alignment: .top)
    .background(AppColor.Preview.lightCyanBackdrop)
}
