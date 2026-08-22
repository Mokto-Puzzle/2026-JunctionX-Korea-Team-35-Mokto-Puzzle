import SwiftUI
import MapKit
import UIKit

struct JellyMapView: View {
    @StateObject private var model: JellyMapViewModel
    @StateObject private var location = LocationManager()
    @State private var mapPosition: MapCameraPosition = .camera(MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 36.42, longitude: 129.43),
        distance: 175_000,
        heading: 0,
        pitch: 0
    ))
    @State private var showComparison = false
    @State private var showLayerMenu = false
    @State private var searchSheetPresented = true
    @State private var searchSheetDetent: PresentationDetent = .height(126)
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
                    filterDismissOverlay
                    layerMenu
                        .padding(.horizontal, 20)
                        .padding(.top, Self.layerMenuTop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
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
            if Self.gyeongbukMapRect.contains(MKMapPoint(location.coordinate)) {
                model.focusNearby(location.coordinate)
                mapPosition = model.position
            } else {
                model.position = Self.gyeongbukMapPosition
                mapPosition = Self.gyeongbukMapPosition
            }
        }
        .onChange(of: searchFocused) { _, focused in
            withAnimation(.snappy) {
                searchExpanded = focused && sheetBeach == nil
                resultSheetExpanded = focused || resultSheetExpanded || searchSheetDetent != Self.collapsedSearchDetent
                if focused {
                    showLayerMenu = false
                    if searchSheetDetent == Self.collapsedSearchDetent {
                        searchSheetDetent = Self.resultSearchDetent
                    }
                }
            }
        }
        .onChange(of: searchSheetDetent) { _, detent in
            withAnimation(.snappy) {
                resultSheetExpanded = detent != Self.collapsedSearchDetent
                if detent == Self.collapsedSearchDetent {
                    searchFocused = false
                    searchExpanded = false
                } else if shouldFocusSearch(for: detent) {
                    searchExpanded = true
                    focusSearchFieldAfterSheetSettles()
                } else {
                    searchExpanded = sheetBeach == nil && !model.searchText.isEmpty
                }
            }
        }
        .fullScreenCover(isPresented: $showComparison) {
            NearbyComparisonView(model: model, userCoordinate: location.coordinate)
        }
        .onChange(of: showComparison) { _, isPresented in
            guard !isPresented else { return }
            collapseSearchSheet(clearSelection: true)
        }
        .sheet(isPresented: $searchSheetPresented) {
            systemSearchSheet
                .presentationDetents(
                    [Self.collapsedSearchDetent, Self.resultSearchDetent, Self.expandedSearchDetent],
                    selection: $searchSheetDetent
                )
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(38)
                .presentationBackground(AppColor.Fill.searchSheetSurface)
                .presentationBackgroundInteraction(.enabled(upThrough: Self.collapsedSearchDetent))
                .presentationContentInteraction(.resizes)
                .interactiveDismissDisabled()
        }
        .tint(AppColor.Text.accent)
        .preferredColorScheme(.light)
    }

    private var map: some View {
        return Map(position: $mapPosition, bounds: Self.gyeongbukCameraBounds, interactionModes: [.pan, .zoom]) {
            UserAnnotation()

            ForEach(visibleMapBeaches) { beach in
                Annotation("", coordinate: beach.coordinate, anchor: .bottom) {
                    Button {
                        withAnimation(.snappy) {
                            focus(on: beach)
                            model.searchText = beach.searchDisplayName
                            searchExpanded = false
                            searchFocused = false
                            resultSheetExpanded = true
                            searchSheetDetent = Self.resultSearchDetent
                            showLayerMenu = false
                        }
                    } label: {
                        BeachPin(
                            beach: beach,
                            risk: displayRisk(for: beach),
                            selected: model.selectedBeach?.id == beach.id,
                            usesMockRisk: model.recommendationUsesMockData(for: beach),
                            showsRadius: visualizeTemperature,
                            temperature: model.selectedLayers.contains(.temperature)
                                ? String(format: "%.0f°C", beach.marine.waterTemperature)
                                : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(beach.displayName), \(model.risk(for: beach).title)")
                }
            }

            ForEach(model.tracks) { track in
                let trackRisk = jellyfishRisk(for: track)

                if model.selectedLayers.contains(.predictedPath) {
                    let history = track.historyPath(at: model.forecastHour)
                    let forecast = track.forecastPath(at: model.forecastHour)
                    let displayedParticles = Array(track.particles(at: model.forecastHour).enumerated())
                        .filter { $0.offset.isMultiple(of: 12) }

                    if history.count > 1 {
                        MapPolyline(coordinates: history)
                            .stroke(AppColor.Map.routeHistory, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                    if forecast.count > 1 {
                        MapPolyline(coordinates: forecast)
                            .stroke(AppColor.Text.accent.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 7]))
                    }
                    if model.forecastHour > 0 {
                        ForEach(displayedParticles, id: \.offset) { item in
                            MapCircle(center: item.element.coordinate, radius: item.element.isBeached ? 260 : 180)
                                .foregroundStyle(item.element.isBeached ? AppColor.Map.beachedParticle : AppColor.Text.accent.opacity(0.26))
                        }
                    }
                    MapCircle(center: track.coordinate(at: model.forecastHour), radius: track.uncertaintyRadius(at: model.forecastHour))
                        .foregroundStyle(AppColor.LegacyTracker.coral.opacity(model.forecastHour == 0 ? 0.13 : 0.10))
                            .stroke(AppColor.LegacyTracker.coral.opacity(0.36), lineWidth: 1)
                }

                Annotation("", coordinate: track.coordinate(at: model.forecastHour)) {
                    MainMapJellyfishMarker(risk: trackRisk)
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
                        .foregroundStyle(AppColor.Text.accent)
                        .padding(6)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 9))
                    }
                }
            }

        }
        .id("\(model.beaches.count)-\(model.tracks.count)")
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls { MapScaleView() }
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

    private var filterDismissOverlay: some View {
        AppColor.Fill.transparentOverlay
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) {
                    showLayerMenu = false
                }
            }
    }

    private func bottomControls(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            if searchSheetDetent != Self.expandedSearchDetent {
                MainMapFloatingControls(onNearMe: centerOnUserLocation, onCompare: presentComparison)
                    .padding(.bottom, floatingControlsBottomPadding)
            }
        }
    }

    private var systemSearchSheet: some View {
        MainMapSystemSearchSheet(
            searchText: $model.searchText,
            searchFocused: $searchFocused,
            isSearchFocused: searchFocused,
            selectedBeach: sheetBeach,
            searchExpanded: searchExpanded,
            isDetailExpanded: searchSheetDetent == Self.expandedSearchDetent,
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
            onSelectBeach: selectSearchResult(_:)
        )
    }

    private var floatingControlsBottomPadding: CGFloat {
        searchSheetDetent == Self.resultSearchDetent
            ? Self.resultSearchHeight + 20
            : Self.collapsedSheetHeight + 12
    }

    private func centerOnUserLocation() {
        collapseSearchSheet(clearSelection: true)
        let target = mapCoordinate(for: location.coordinate)
        let position = MapCameraPosition.camera(MapCamera(
            centerCoordinate: target,
            distance: 55_000,
            heading: 0,
            pitch: 0
        ))
        model.position = position
        mapPosition = position
    }

    private func presentComparison() {
        collapseSearchSheet(clearSelection: true)
        showComparison = true
    }

    private func collapseSearchSheet(clearSelection: Bool) {
        searchFocused = false
        searchExpanded = false
        resultSheetExpanded = false
        searchSheetDetent = Self.collapsedSearchDetent
        if clearSelection {
            model.searchText = ""
            model.selectedBeach = nil
            model.focusedBeach = nil
        }
    }

    private func clearSearch() {
        collapseSearchSheet(clearSelection: true)
    }

    private func summaryContent(for beach: Beach) -> BeachResultSummaryContent {
        BeachResultSummaryContent(
            beach: beach,
            risk: displayRisk(for: beach),
            jellyfishText: beach.recentJellyfish ? "\(beach.recentSightingsCount) recent" : "None",
            currentText: String(format: "%.2f m/s", beach.marine.currentSpeed),
            waterText: String(format: "%.1f°C", beach.marine.waterTemperature),
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

    private static var gyeongbukMapPosition: MapCameraPosition {
        .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 36.42, longitude: 129.43),
            distance: 175_000,
            heading: 0,
            pitch: 0
        ))
    }

    private func focusInitialMap() {
        if location.isUsingFallback || !Self.gyeongbukMapRect.contains(MKMapPoint(location.coordinate)) {
            model.position = Self.gyeongbukMapPosition
            mapPosition = Self.gyeongbukMapPosition
        } else {
            model.focusNearby(location.coordinate)
            mapPosition = model.position
        }
    }

    private func mapCoordinate(for coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if !location.isUsingFallback && Self.gyeongbukMapRect.contains(MKMapPoint(coordinate)) {
            return coordinate
        }
        return LocationManager.fallback
    }

    private func errorToast(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(AppColor.Icon.warning)
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
        resultSheetExpanded = true
        searchSheetDetent = Self.resultSearchDetent
    }

    private func shouldFocusSearch(for detent: PresentationDetent) -> Bool {
        detent == Self.resultSearchDetent
            && model.searchText.isEmpty
            && model.selectedBeach == nil
    }

    private func focusSearchFieldAfterSheetSettles() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard shouldFocusSearch(for: searchSheetDetent) else { return }
            searchFocused = true
        }
    }

    private func focus(on beach: Beach) {
        model.focus(on: beach)
        mapPosition = model.position
    }

    private func jellyfishRisk(for track: JellyfishTrack) -> RiskLevel {
        let coordinate = track.coordinate(at: model.forecastHour)
        guard let nearestBeach = model.beaches.min(by: {
            model.distance(from: coordinate, to: $0.coordinate) < model.distance(from: coordinate, to: $1.coordinate)
        }) else {
            return .unknown
        }
        return model.risk(for: nearestBeach)
    }

    private static let collapsedSheetHeight: CGFloat = 126
    private static let collapsedSearchDetent = PresentationDetent.height(collapsedSheetHeight)
    private static let resultSearchHeight: CGFloat = 304
    private static let expandedSearchHeight: CGFloat = 550
    private static let resultSearchDetent = PresentationDetent.height(resultSearchHeight)
    private static let expandedSearchDetent = PresentationDetent.height(expandedSearchHeight)
    private static let layerMenuTop: CGFloat = 246
    private static let gyeongbukCameraBounds = MapCameraBounds(
        centerCoordinateBounds: gyeongbukMapRect,
        minimumDistance: 18_000,
        maximumDistance: 260_000
    )
    private static let gyeongbukMapRect: MKMapRect = {
        let southWest = MKMapPoint(CLLocationCoordinate2D(latitude: 35.45, longitude: 128.95))
        let northEast = MKMapPoint(CLLocationCoordinate2D(latitude: 37.25, longitude: 129.90))
        return MKMapRect(
            x: min(southWest.x, northEast.x),
            y: min(southWest.y, northEast.y),
            width: abs(northEast.x - southWest.x),
            height: abs(southWest.y - northEast.y)
        )
    }()
}

#Preview("Jelly Map") {
    JellyMapView(provider: MockOceanDataProvider())
}
