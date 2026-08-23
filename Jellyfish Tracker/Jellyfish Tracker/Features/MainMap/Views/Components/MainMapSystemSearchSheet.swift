import SwiftUI

struct MainMapSystemSearchSheet: View {
    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding
    let isSearchFocused: Bool
    let selectedBeach: Beach?
    let searchExpanded: Bool
    let isCollapsed: Bool
    let isDetailExpanded: Bool
    let filteredBeaches: [Beach]
    let riskForBeach: (Beach) -> RiskLevel
    let markedRiskForBeach: (Beach) -> String
    let distanceTextForBeach: (Beach) -> String
    let summaryForBeach: (Beach) -> BeachResultSummaryContent
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onSelectBeach: (Beach) -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetGrabber
                .padding(.top, 7)

            Spacer()
                .frame(height: searchFieldTopGap)

            searchField
                .padding(.horizontal, 20)

            if let selectedBeach {
                let content = summaryForBeach(selectedBeach)
                if isCollapsed {
                    BeachCollapsedPreview(content: content)
                        .padding(.horizontal, 20)
                        .padding(.top, 17)
                        .transition(.opacity)
                } else {
                    BeachResultSummary(content: content)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if isDetailExpanded {
                    BeachResultExpandedDetails(content: content)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else if searchExpanded && !searchText.isEmpty {
                searchResults
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
        .id(contentIdentity)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
                .fill(.ultraThinMaterial)
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
                        .fill(AppColor.Fill.searchSheetSurface)
                }
                .padding(.bottom, -80)
                .ignoresSafeArea(edges: .bottom)
        }
        .padding(.horizontal, isSearchFocused ? 6 : 0)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.88), value: isSearchFocused)
    }

    private var sheetGrabber: some View {
        Capsule()
            .fill(AppColor.Text.caption.opacity(0.48))
            .frame(width: 36, height: 5)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColor.Icon.secondary)
            TextField("Search", text: $searchText)
                .focused(searchFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(AppColor.Icon.secondary)
                .accessibilityLabel("Clear search")
            } else {
                Image(systemName: "mic.fill").foregroundStyle(AppColor.Icon.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(searchFieldFill, in: .capsule)
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredBeaches.prefix(6)), id: \.id) { beach in
                    Button { onSelectBeach(beach) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(AppColor.risk(riskForBeach(beach)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(beach.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.Text.normal)
                                Text("\(beach.displayCity) · \(distanceTextForBeach(beach))")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.Text.secondary)
                            }
                            Spacer()
                            Text(markedRiskForBeach(beach))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColor.risk(riskForBeach(beach)))
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if beach.id != filteredBeaches.prefix(6).last?.id {
                        Divider()
                    }
                }
                if filteredBeaches.isEmpty {
                    ContentUnavailableView("No beaches found", systemImage: "magnifyingglass")
                        .padding(.vertical, 18)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private var searchFieldTopGap: CGFloat { searchFieldTopFromSheet - 7 - 5 }
    private var searchFieldTopFromSheet: CGFloat { 41 }
    private var searchFieldFill: Color {
        AppColor.Fill.secondary
    }

    private var contentIdentity: String {
        [
            isCollapsed ? "collapsed" : "raised",
            isDetailExpanded ? "detail" : "summary",
            selectedBeach?.id ?? "search",
            searchExpanded ? "results" : "idle"
        ].joined(separator: "-")
    }
}

private struct BeachCollapsedPreview: View {
    let content: BeachResultSummaryContent

    var body: some View {
        HStack(spacing: 10) {
            RiskStatusChip(
                risk: content.risk,
                height: 28,
                iconSize: 15,
                fontSize: 12,
                horizontalPadding: 10
            )

            Text(content.beach.displayName)
                .font(.custom("Helvetica-Bold", size: 16, relativeTo: .subheadline))
                .foregroundStyle(AppColor.Text.normal)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(height: 42, alignment: .top)
        .opacity(0.86)
        .allowsHitTesting(false)
    }
}

private struct BeachResultExpandedDetails: View {
    let content: BeachResultSummaryContent

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(safetySummary)
                .font(.custom("Helvetica-Bold", size: 18, relativeTo: .headline))
                .foregroundStyle(AppColor.Text.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.Fill.Button.accent, in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 10) {
                Text("Selected Time")
                    .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                    .foregroundStyle(AppColor.Text.caption)
                Text(selectedTimeText)
                    .font(.custom("Helvetica", size: 18, relativeTo: .body))
                    .foregroundStyle(AppColor.Text.normal)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Activity Status")
                    .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                    .foregroundStyle(AppColor.Text.caption)

                HStack(spacing: 9) {
                    activityChip("Swim", group: .calmWater, fill: AppColor.Fill.StatusChip.safe, foreground: AppColor.Status.safe)
                    activityChip("Surf", group: .board, fill: AppColor.Fill.StatusChip.surf, foreground: AppColor.Status.surf)
                    activityChip("Fish", group: .offshore, fill: AppColor.Fill.StatusChip.fish, foreground: AppColor.Status.fish)
                }
            }
        }
    }

    private var safetySummary: String {
        "At \(relativeTimeText), modeled jellyfish impact is \(jellyfishPhrase) (\(Int((content.impactProbability * 100).rounded()))%), and waves are \(wavePhrase)."
    }

    private var relativeTimeText: String {
        let hour = Int(content.forecastHour.rounded())
        if hour == 0 { return "the current time" }
        return hour > 0 ? "+\(hour)h" : "\(abs(hour))h ago"
    }

    private var selectedTimeText: String {
        let date = Date().addingTimeInterval(content.forecastHour * 3_600)
        return Self.timeFormatter.string(from: date) + (content.forecastHour == 0 ? " · Now" : " · \(relativeTimeText)")
    }

    private func activityChip(
        _ name: String, group: ActivityGroup, fill: Color, foreground: Color
    ) -> some View {
        let status = content.activityStatuses[group] ?? .unknown
        return BeachActivityChip(
            title: "\(name) · \(status.shortTitle)",
            fill: fill,
            foreground: foreground
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    private var jellyfishPhrase: String {
        if content.impactProbability >= 0.55 { return "high" }
        if content.impactProbability >= 0.18 { return "moderate" }
        return "low"
    }

    private var wavePhrase: String {
        content.beach.marine.waveHeight < 0.7 ? "calm" : "active"
    }
}

private struct BeachActivityChip: View {
    let title: String
    let fill: Color
    let foreground: Color

    var body: some View {
        Text(title)
            .font(.custom("Helvetica", size: 13, relativeTo: .caption))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 31)
            .background(fill, in: .capsule)
    }
}

private struct MainMapSystemSearchSheetPreview: View {
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        MainMapSystemSearchSheet(
            searchText: $searchText,
            searchFocused: $searchFocused,
            isSearchFocused: true,
            selectedBeach: nil,
            searchExpanded: true,
            isCollapsed: false,
            isDetailExpanded: false,
            filteredBeaches: MockOceanDataProvider.beaches,
            riskForBeach: { $0.baseRisk },
            markedRiskForBeach: { $0.baseRisk.shortTitle },
            distanceTextForBeach: { _ in "1.2 km" },
            summaryForBeach: { beach in
                BeachResultSummaryContent(
                    beach: beach,
                    risk: .good,
                    jellyfishText: "None",
                    currentText: "0.06 m/s",
                    waterText: "24.2°C",
                    usesMockRisk: true
                )
            },
            onSubmit: {},
            onClear: { searchText = "" },
            onSelectBeach: { _ in }
        )
        .frame(width: 402, height: 550)
        .background(AppColor.Preview.cyanBackdrop)
    }
}

#Preview("System Search Sheet") {
    MainMapSystemSearchSheetPreview()
}
