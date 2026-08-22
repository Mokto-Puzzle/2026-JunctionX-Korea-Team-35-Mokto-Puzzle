import SwiftUI

struct MainMapSearchSheet: View {
    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding
    let bottomInset: CGFloat
    let selectedBeach: Beach?
    let searchExpanded: Bool
    @Binding var resultSheetExpanded: Bool
    let filteredBeaches: [Beach]
    let riskForBeach: (Beach) -> RiskLevel
    let markedRiskForBeach: (Beach) -> String
    let distanceTextForBeach: (Beach) -> String
    let summaryForBeach: (Beach) -> BeachResultSummaryContent
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onSelectBeach: (Beach) -> Void
    let onDragExpansionChange: (Bool) -> Void
    @GestureState private var sheetDragTranslation: CGFloat = 0

    var body: some View {
        sheetContent
            .frame(height: interactiveSheetHeight, alignment: .top)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
                            .fill(Color.white.opacity(0.28))
                    }
                    .padding(.bottom, -bottomInset)
                    .ignoresSafeArea(edges: .bottom)
            }
            .shadow(color: .black.opacity(0.12), radius: 25, y: -4)
            .contentShape(.rect)
            .gesture(sheetDragGesture)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.88), value: resultSheetExpanded)
    }

    private var sheetContent: some View {
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
            } else if searchExpanded {
                searchResults
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

            if resultSheetExpanded {
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 16)
        .clipped()
    }

    private var sheetGrabber: some View {
        Capsule()
            .fill(Color.jellyCaption.opacity(0.48))
            .frame(width: 36, height: 5)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .focused(searchFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear search")
            } else {
                Image(systemName: "mic.fill").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AppColor.Primitive.Common.shade100.opacity(0.58), in: .capsule)
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredBeaches.prefix(6)), id: \.id) { beach in
                    Button { onSelectBeach(beach) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.risk(riskForBeach(beach)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(beach.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.jellyInk)
                                Text("\(beach.displayCity) · \(distanceTextForBeach(beach))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(markedRiskForBeach(beach))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.risk(riskForBeach(beach)))
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

    private var restingSheetHeight: CGFloat {
        if isCollapsedSearchOnly {
            return collapsedSheetVisualHeight
        }
        if resultSheetExpanded { return expandedSheetHeight }
        return selectedBeach == nil ? 104 + bottomInset : 304 + bottomInset
    }

    private var interactiveSheetHeight: CGFloat {
        let baseHeight = restingSheetHeight
        guard sheetDragTranslation != 0 else { return baseHeight }

        if sheetDragTranslation < 0 {
            return min(expandedSheetHeight, baseHeight + abs(sheetDragTranslation))
        }

        if resultSheetExpanded {
            return max(collapsedSheetVisualHeight, baseHeight - sheetDragTranslation)
        }

        return baseHeight
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($sheetDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let shouldExpand = value.translation.height < -36 || value.predictedEndTranslation.height < -96
                let shouldCollapse = value.translation.height > 36 || value.predictedEndTranslation.height > 96

                withAnimation(.snappy) {
                    if shouldExpand {
                        resultSheetExpanded = true
                        onDragExpansionChange(true)
                    } else if shouldCollapse {
                        resultSheetExpanded = false
                        onDragExpansionChange(false)
                    }
                }
            }
    }

    private var isCollapsedSearchOnly: Bool {
        selectedBeach == nil && !searchExpanded && !resultSheetExpanded
    }

    private var collapsedSheetVisualHeight: CGFloat { 126 }
    private var searchFieldTopFromSheet: CGFloat { 41 }
    private var searchFieldTopGap: CGFloat { searchFieldTopFromSheet - 7 - 5 }
    private var expandedSheetHeight: CGFloat { 550 + bottomInset }
}

struct BeachResultSummaryContent {
    let beach: Beach
    let risk: RiskLevel
    let jellyfishText: String
    let currentText: String
    let waterText: String
    let usesMockRisk: Bool
}

struct BeachResultSummary: View {
    let content: BeachResultSummaryContent

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ResultRiskBadge(risk: content.risk, usesMockRisk: content.usesMockRisk)
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.beach.displayName)
                        .font(.custom("Helvetica-Bold", size: 18, relativeTo: .headline))
                        .foregroundStyle(Color.jellyInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(content.beach.displayCity), Gyeongsangbuk-do")
                        .font(.custom("Helvetica", size: 13, relativeTo: .caption))
                        .foregroundStyle(Color.jellyCaption)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                ResultMetric(assetName: "IconJellyfish", title: "jellyfish", value: content.jellyfishText)
                Divider().overlay(AppColor.Primitive.Common.shade100)
                ResultMetric(assetName: "IconCurrent", title: "current", value: content.currentText)
                Divider().overlay(AppColor.Primitive.Common.shade100)
                ResultMetric(assetName: "IconWater", title: "water", value: content.waterText)
            }
            .frame(height: 100)
            .background(Color.white.opacity(0.62), in: .rect(cornerRadius: 16))
        }
    }
}

private struct ResultRiskBadge: View {
    let risk: RiskLevel
    let usesMockRisk: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image("IconJellyfish")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(risk.shortTitle.uppercased() + (usesMockRisk ? "" : ""))
                .font(.custom("Helvetica", size: 12, relativeTo: .caption))
        }
        .foregroundStyle(Color.jellyMint)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(AppColor.Primitive.Green.shade100.opacity(0.72), in: .capsule)
    }
}

private struct ResultMetric: View {
    let assetName: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.jellyMint)
            Text(title)
                .font(.custom("Helvetica", size: 13, relativeTo: .caption))
                .foregroundStyle(Color.jellyCaption)
            Text(value)
                .font(.custom("Helvetica-Bold", size: 18, relativeTo: .body))
                .foregroundStyle(Color.jellyInk)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MainMapSearchSheetPreview: View {
    @State private var searchText = "Chilpo"
    @State private var resultSheetExpanded = false
    @FocusState private var searchFocused: Bool

    private let beach = MockOceanDataProvider.beaches.first { $0.id == "chilpo" } ?? MockOceanDataProvider.beaches[0]

    var body: some View {
        MainMapSearchSheet(
            searchText: $searchText,
            searchFocused: $searchFocused,
            bottomInset: 34,
            selectedBeach: beach,
            searchExpanded: false,
            resultSheetExpanded: $resultSheetExpanded,
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
            onSelectBeach: { _ in },
            onDragExpansionChange: { _ in }
        )
        .frame(width: 402, height: 330, alignment: .bottom)
        .background(Color(red: 0.78, green: 0.94, blue: 1.0))
    }
}

#Preview("Search Sheet") {
    MainMapSearchSheetPreview()
}

#Preview("Search Sheet Collapsed") {
    @Previewable @State var searchText = ""
    @Previewable @State var resultSheetExpanded = false
    @FocusState var searchFocused: Bool

    MainMapSearchSheet(
        searchText: $searchText,
        searchFocused: $searchFocused,
        bottomInset: 34,
        selectedBeach: nil,
        searchExpanded: false,
        resultSheetExpanded: $resultSheetExpanded,
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
        onClear: {},
        onSelectBeach: { _ in },
        onDragExpansionChange: { _ in }
    )
    .frame(width: 402, height: 126, alignment: .bottom)
    .background(Color(red: 0.78, green: 0.94, blue: 1.0))
}
