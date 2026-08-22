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
                        .foregroundStyle(Color.jellyCaption)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(beachName)
                                .foregroundStyle(Color.jellyMint)
                            Text("is your")
                                .foregroundStyle(Color.jellyInk)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        Text("safest choice today!")
                            .foregroundStyle(Color.jellyInk)
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
        .shadow(color: Color.jellyMint.opacity(0.08), radius: 16, y: 8)
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
                .foregroundStyle(Color.jellyMint)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.42), in: .circle)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.68), lineWidth: 1)
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
                .foregroundStyle(Color.jellyCaption)
            Slider(value: Binding(
                get: { value },
                set: { newValue in
                    withAnimation(.linear(duration: 0.12)) { value = newValue }
                }
            ), in: -24...24, step: 1)
                .tint(Color.jellyMint)
                .accessibilityLabel("Jellyfish timeline")
            Text("+24h")
                .frame(width: 40, alignment: .trailing)
                .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                .foregroundStyle(Color.jellyCaption)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.58), in: .capsule)
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
    .background(Color(red: 0.75, green: 0.94, blue: 1.0))
}
