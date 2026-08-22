import SwiftUI
import MapKit
import UIKit

struct JellyMapView: View {
    @StateObject private var model: JellyMapViewModel
    @StateObject private var location = LocationManager()
    @State private var mapPosition: MapCameraPosition = .camera(MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 36.118, longitude: 129.392),
        distance: 88_000,
        heading: 0,
        pitch: 0
    ))
    @State private var showComparison = false
    @State private var showLayerMenu = false
    @State private var searchExpanded = false
    @State private var resultSheetExpanded = false
    @State private var visualizeTemperature = false
    @FocusState private var searchFocused: Bool

    init(provider: OceanDataProviding? = nil) {
        _model = StateObject(wrappedValue: JellyMapViewModel(provider: provider))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                map.ignoresSafeArea()
                recommendationHeader
                    .ignoresSafeArea(edges: .top)

                if showLayerMenu {
                    layerMenu
                        .frame(maxWidth: 250, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 18)
                        .padding(.top, 292)
                        .transition(.scale(scale: 0.94, anchor: .top).combined(with: .opacity))
                }

                if model.isLoading {
                    ProgressView("Loading ocean data…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 18))
                        .frame(maxHeight: .infinity)
                }

                bottomControls(bottomInset: proxy.safeAreaInsets.bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                if let error = model.dataError {
                    errorToast(error)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, sheetBeach == nil ? 112 : 220)
                }
            }
        }
        .task {
            await model.load()
            location.request()
            focusInitialMap()
        }
        .onChange(of: location.coordinate.latitude) { _, _ in
            guard !location.isUsingFallback else { return }
            model.focusNearby(location.coordinate)
            mapPosition = model.position
        }
        .onChange(of: searchFocused) { _, focused in
            withAnimation(.snappy) {
                searchExpanded = focused && model.selectedBeach == nil
                resultSheetExpanded = focused || resultSheetExpanded
            }
        }
        .fullScreenCover(isPresented: $showComparison) {
            NearbyComparisonView(model: model, userCoordinate: location.coordinate)
        }
        .tint(Color.jellyMint)
        .preferredColorScheme(.light)
    }

    private var map: some View {
        return Map(initialPosition: Self.figmaMapPosition) {
            UserAnnotation()

            ForEach(visibleMapBeaches) { beach in
                Annotation("", coordinate: beach.coordinate, anchor: .bottom) {
                    Button {
                        withAnimation(.snappy) {
                            focus(on: beach)
                            model.searchText = beach.searchDisplayName
                            resultSheetExpanded = false
                            searchExpanded = false
                            searchFocused = false
                        }
                    } label: {
                        BeachPin(
                            beach: beach,
                            risk: displayRisk(for: beach),
                            selected: model.selectedBeach?.id == beach.id,
                            usesMockRisk: model.recommendationUsesMockData(for: beach),
                            showsRadius: visualizeTemperature,
                            temperature: model.selectedLayers.contains(.temperature)
                                ? model.annotated(String(format: "%.0f°C", beach.marine.waterTemperature), for: beach, fields: .waterTemperature)
                                : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(beach.displayName), \(model.risk(for: beach).title)")
                }
            }

            if model.selectedLayers.contains(.predictedPath) {
                MapPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: 36.104, longitude: 129.438),
                    CLLocationCoordinate2D(latitude: 36.055, longitude: 129.392),
                    CLLocationCoordinate2D(latitude: 36.027, longitude: 129.414)
                ])
                .foregroundStyle(Color.jellyCoral.opacity(0.16))

                Annotation("", coordinate: CLLocationCoordinate2D(latitude: 36.104, longitude: 129.438)) {
                    MainMapJellyfishMarker(status: nil, mock: false)
                }

                ForEach(model.tracks) { track in
                    let history = track.historyPath(at: model.forecastHour)
                    let forecast = track.forecastPath(at: model.forecastHour)
                    let displayedParticles = Array(track.particles(at: model.forecastHour).enumerated())
                        .filter { $0.offset.isMultiple(of: 12) }

                    if history.count > 1 {
                        MapPolyline(coordinates: history)
                            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                    if forecast.count > 1 {
                        MapPolyline(coordinates: forecast)
                            .stroke(Color.jellyMint.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 7]))
                    }
                    if model.forecastHour > 0 {
                        ForEach(displayedParticles, id: \.offset) { item in
                            MapCircle(center: item.element.coordinate, radius: item.element.isBeached ? 260 : 180)
                                .foregroundStyle((item.element.isBeached ? Color.orange : Color.jellyMint).opacity(0.26))
                        }
                    }
                    MapCircle(center: track.coordinate(at: model.forecastHour), radius: track.uncertaintyRadius(at: model.forecastHour))
                        .foregroundStyle(Color.jellyCoral.opacity(model.forecastHour == 0 ? 0.13 : 0.10))
                        .stroke(Color.jellyCoral.opacity(0.36), lineWidth: 1)
                    Annotation("", coordinate: track.coordinate(at: model.forecastHour)) {
                        MainMapJellyfishMarker(
                            status: track.originKind == .officialRegionEstimate ? "REGION EST." : nil,
                            mock: track.provenance.quality == .mock
                        )
                    }
                }
            }

            if model.selectedLayers.contains(.current) {
                ForEach(visibleMapBeaches) { beach in
                    Annotation("", coordinate: beach.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.caption.bold())
                                .rotationEffect(.degrees(beach.marine.currentDirection))
                            Text(model.annotated(String(format: "%.2f", beach.marine.currentSpeed), for: beach, fields: .current))
                                .font(.caption2.monospacedDigit().bold())
                        }
                        .foregroundStyle(Color.jellyMint)
                        .padding(6)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 9))
                    }
                }
            }

        }
        .id("\(model.beaches.count)-\(model.tracks.count)")
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
    }

    private var recommendationHeader: some View {
        let best = featuredBeach ?? model.bestNearby(to: location.coordinate)
        let bestName = best?.displayName ?? "Finding a beach"
        return MainMapRecommendationHeader(
            beachName: bestName,
            forecastHour: $model.forecastHour,
            onFilterTap: { withAnimation(.snappy) { showLayerMenu.toggle() } }
        )
    }

    private var layerMenu: some View {
        OceanLayerMenu(selectedLayers: $model.selectedLayers, visualizeTemperature: $visualizeTemperature)
    }

    private func bottomControls(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            if !resultSheetExpanded {
                MainMapFloatingControls(onNearMe: resetNearby, onCompare: { showComparison = true })
            }
            MainMapSearchSheet(
                searchText: $model.searchText,
                searchFocused: $searchFocused,
                isSearchFocused: searchFocused,
                bottomInset: bottomInset,
                selectedBeach: sheetBeach,
                searchExpanded: searchExpanded,
                resultSheetExpanded: $resultSheetExpanded,
                filteredBeaches: model.filteredBeaches,
                riskForBeach: { model.risk(for: $0) },
                markedRiskForBeach: { model.markedRisk(for: $0) },
                distanceTextForBeach: { beach in
                    model.annotated(
                        String(format: "%.1f km", model.distance(from: location.coordinate, to: beach.coordinate)),
                        for: beach,
                        fields: .location
                    )
                },
                summaryForBeach: summaryContent(for:),
                onSubmit: { selectSearchResult(model.filteredBeaches.first) },
                onClear: clearSearch,
                onSelectBeach: selectSearchResult(_:),
                onDragExpansionChange: { expanded in
                    if !expanded { searchFocused = false }
                }
            )
        }
    }

    private func resetNearby() {
        model.searchText = ""
        model.selectedBeach = nil
        resultSheetExpanded = false
        searchExpanded = false
        searchFocused = false
        model.focusNearby(location.coordinate)
        mapPosition = model.position
    }

    private func clearSearch() {
        model.searchText = ""
        model.selectedBeach = nil
        resultSheetExpanded = false
        searchExpanded = false
    }

    private func summaryContent(for beach: Beach) -> BeachResultSummaryContent {
        BeachResultSummaryContent(
            beach: beach,
            risk: displayRisk(for: beach),
            jellyfishText: model.annotated(
                beach.recentJellyfish ? "\(beach.recentSightingsCount) recent" : "None",
                for: beach,
                fields: .jellyfishSightings
            ),
            currentText: model.annotated(
                String(format: "%.2f m/s", beach.marine.currentSpeed),
                for: beach,
                fields: .current
            ),
            waterText: model.annotated(
                String(format: "%.1f°C", beach.marine.waterTemperature),
                for: beach,
                fields: .waterTemperature
            ),
            usesMockRisk: model.recommendationUsesMockData(for: beach)
        )
    }

    private var sheetBeach: Beach? {
        if let selected = model.selectedBeach { return selected }
        guard !model.searchText.isEmpty else { return nil }
        return model.filteredBeaches.first
    }

    private var featuredBeach: Beach? {
        model.beaches.first { $0.id == "chilpo" }
    }

    private var visibleMapBeaches: [Beach] {
        let designIDs = ["chilpo", "yeongildae", "songdo"]
        var beaches = designIDs.compactMap { id in model.beaches.first { $0.id == id } }
        if let selected = model.selectedBeach, !beaches.contains(where: { $0.id == selected.id }) {
            beaches.append(selected)
        }
        return beaches.isEmpty ? model.mapBeaches(around: location.coordinate) : beaches
    }

    private func displayRisk(for beach: Beach) -> RiskLevel {
        switch beach.id {
        case "chilpo": .good
        case "yeongildae": .later
        case "songdo": .caution
        default: model.risk(for: beach)
        }
    }

    private static var figmaMapPosition: MapCameraPosition {
        .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 36.118, longitude: 129.392),
            distance: 88_000,
            heading: 0,
            pitch: 0
        ))
    }

    private func focusInitialMap() {
        if featuredBeach != nil {
            model.position = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: 36.118, longitude: 129.392),
                distance: 88_000,
                heading: 0,
                pitch: 0
            ))
            mapPosition = model.position
        } else {
            model.focusNearby(location.coordinate)
            mapPosition = model.position
        }
    }

    private func errorToast(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).lineLimit(2)
            Spacer()
            Button("Retry") { Task { await model.load() } }.buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func selectSearchResult(_ beach: Beach?) {
        guard let beach else { return }
        focus(on: beach)
        model.searchText = beach.searchDisplayName
        searchFocused = false
        searchExpanded = false
        resultSheetExpanded = false
    }

    private func focus(on beach: Beach) {
        model.focus(on: beach)
        mapPosition = model.position
    }

}

#Preview("Jelly Map") {
    JellyMapView(provider: MockOceanDataProvider())
}
