import SwiftUI

struct MainMapSystemSearchSheet: View {
    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding
    let isSearchFocused: Bool
    let selectedBeach: Beach?
    let searchExpanded: Bool
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
                BeachResultSummary(content: summaryForBeach(selectedBeach))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if searchExpanded && !searchText.isEmpty {
                searchResults
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
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
        isSearchFocused ? AppColor.Fill.secondary : AppColor.Fill.translucentControl
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
