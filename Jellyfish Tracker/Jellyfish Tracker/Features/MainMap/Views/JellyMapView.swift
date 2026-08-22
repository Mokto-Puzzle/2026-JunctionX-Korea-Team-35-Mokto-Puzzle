import SwiftUI
import MapKit
import UIKit

struct JellyMapView: View {
    @StateObject private var model = JellyMapViewModel()
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

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                map.ignoresSafeArea()
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: proxy.safeAreaInsets.top + 8)
                    .ignoresSafeArea(edges: .top)
                recommendationHeader

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
                    JellyfishMarker(status: nil, mock: false)
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
                        JellyfishMarker(
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
        return VStack(alignment: .leading, spacing: 14) {
            Image("JellyMark")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 18, alignment: .leading)
                .padding(.top, 4)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(Date.now.formatted(.dateTime.month(.wide).day().year()))
                        .font(.custom("Helvetica", size: 14, relativeTo: .callout))
                        .foregroundStyle(Color.jellyCaption)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(bestName)
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
                Button {
                    withAnimation(.snappy) { showLayerMenu.toggle() }
                } label: {
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

            HStack(spacing: 8) {
                Text("-24h")
                    .frame(width: 40, alignment: .leading)
                    .font(.custom("Helvetica-Bold", size: 14, relativeTo: .caption))
                    .foregroundStyle(Color.jellyCaption)
                Slider(value: Binding(
                    get: { model.forecastHour },
                    set: { value in
                        withAnimation(.linear(duration: 0.12)) { model.forecastHour = value }
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
        .padding(.horizontal, 20)
        .padding(.top, 98)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        AppColor.Primitive.Green.shade050.opacity(0.86),
                        Color(red: 0.75, green: 0.94, blue: 1.0).opacity(0.88)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.95)
                .background(.ultraThinMaterial)
            }
        }
        .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
        .shadow(color: Color.jellyMint.opacity(0.08), radius: 16, y: 8)
    }

    private var layerMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ocean Layers")
                .font(.custom("Helvetica-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.jellyInk)
            layerToggle("Predicted Route", symbol: "point.topleft.down.to.point.bottomright.curvepath", layer: .predictedPath)
            layerToggle("Water Temperature", symbol: "thermometer.variable", layer: .temperature)
            Toggle(isOn: $visualizeTemperature) {
                Label("Visualize Temperature", systemImage: "field.of.view.wide.fill")
                    .foregroundStyle(Color.jellyInk)
            }
            .tint(Color.jellyMint)
            .font(.custom("Helvetica", size: 13, relativeTo: .body))
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 21)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.60))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    private func layerToggle(_ title: String, symbol: String, layer: MapLayer) -> some View {
        Toggle(isOn: Binding(
            get: { model.selectedLayers.contains(layer) },
            set: { enabled in
                if enabled { model.selectedLayers.insert(layer) }
                else { model.selectedLayers.remove(layer) }
            }
        )) {
            Label(title, systemImage: symbol).foregroundStyle(Color.jellyInk)
        }
        .tint(Color.jellyMint)
        .font(.custom("Helvetica", size: 13, relativeTo: .body))
        .padding(.vertical, 4)
    }

    private func bottomControls(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            if !resultSheetExpanded {
                HStack {
                    Button {
                        model.searchText = ""
                        model.selectedBeach = nil
                        resultSheetExpanded = false
                        searchExpanded = false
                        searchFocused = false
                        model.focusNearby(location.coordinate)
                        mapPosition = model.position
                    } label: {
                        Image("IconNearMe")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21, height: 21)
                            .foregroundStyle(Color.jellyMint)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.72), in: .circle)
                            .overlay {
                                Circle().stroke(Color.jellyMint.opacity(0.25), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Near me")
                    Spacer()
                    Button { showComparison = true } label: {
                        HStack(spacing: 8) {
                            Image("IconCompare")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 21, height: 21)
                            Text("Compare")
                                .font(.custom("Helvetica-Bold", size: 16, relativeTo: .callout))
                        }
                        .padding(.horizontal, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
                .padding(.horizontal, 20)
            }
            searchSheet(bottomInset: bottomInset)
        }
    }

    private func searchSheet(bottomInset: CGFloat) -> some View {
        let beach = sheetBeach
        return VStack(spacing: 10) {
            Capsule()
                .fill(Color.jellyCaption.opacity(0.48))
                .frame(width: 36, height: 5)
                .padding(.bottom, 6)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $model.searchText)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { selectSearchResult(model.filteredBeaches.first) }
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                        model.selectedBeach = nil
                        resultSheetExpanded = false
                        searchExpanded = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "mic.fill").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AppColor.Primitive.Common.shade100.opacity(0.58), in: .capsule)

            if let beach {
                BeachResultSummary(
                    beach: beach,
                    risk: displayRisk(for: beach),
                    jellyfishText: model.annotated(beach.recentJellyfish ? "\(beach.recentSightingsCount) recent" : "None", for: beach, fields: .jellyfishSightings),
                    currentText: model.annotated(String(format: "%.2f m/s", beach.marine.currentSpeed), for: beach, fields: .current),
                    waterText: model.annotated(String(format: "%.1f°C", beach.marine.waterTemperature), for: beach, fields: .waterTemperature),
                    usesMockRisk: model.recommendationUsesMockData(for: beach)
                )
                .padding(.top, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if searchExpanded {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.filteredBeaches.prefix(6)), id: \.id) { beach in
                            Button { selectSearchResult(beach) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(Color.risk(model.risk(for: beach)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(beach.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Color.jellyInk)
                                        Text("\(beach.displayCity) · \(model.annotated(String(format: "%.1f km", model.distance(from: location.coordinate, to: beach.coordinate)), for: beach, fields: .location))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(model.markedRisk(for: beach))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.risk(model.risk(for: beach)))
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if beach.id != model.filteredBeaches.prefix(6).last?.id { Divider() }
                        }
                        if model.filteredBeaches.isEmpty {
                            ContentUnavailableView("No beaches found", systemImage: "magnifyingglass")
                                .padding(.vertical, 18)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            if resultSheetExpanded {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 7)
        .padding(.bottom, 16)
        .frame(height: resultSheetHeight(bottomInset: bottomInset), alignment: .top)
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
        .gesture(
            DragGesture(minimumDistance: 16).onEnded { value in
                withAnimation(.snappy) {
                    if value.translation.height < -36 { resultSheetExpanded = true }
                    if value.translation.height > 36 {
                        resultSheetExpanded = false
                        searchFocused = false
                    }
                }
            }
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

    private func resultSheetHeight(bottomInset: CGFloat) -> CGFloat {
        if resultSheetExpanded { return 550 + bottomInset }
        return sheetBeach == nil ? 104 + bottomInset : 304 + bottomInset
    }

    private var timelineStatus: String {
        if model.forecastHour == 0 { return "Current" }
        if model.forecastHour < 0 { return "\(Int(abs(model.forecastHour)))h ago" }
        return "+\(Int(model.forecastHour))h forecast"
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

private struct BeachResultSummary: View {
    let beach: Beach
    let risk: RiskLevel
    let jellyfishText: String
    let currentText: String
    let waterText: String
    let usesMockRisk: Bool

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ResultRiskBadge(risk: risk, usesMockRisk: usesMockRisk)
                VStack(alignment: .leading, spacing: 3) {
                    Text(beach.displayName)
                        .font(.custom("Helvetica-Bold", size: 18, relativeTo: .headline))
                        .foregroundStyle(Color.jellyInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(beach.displayCity), Gyeongsangbuk-do")
                        .font(.custom("Helvetica", size: 13, relativeTo: .caption))
                        .foregroundStyle(Color.jellyCaption)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                ResultMetric(assetName: "IconJellyfish", title: "jellyfish", value: jellyfishText)
                Divider().overlay(AppColor.Primitive.Common.shade100)
                ResultMetric(assetName: "IconCurrent", title: "current", value: currentText)
                Divider().overlay(AppColor.Primitive.Common.shade100)
                ResultMetric(assetName: "IconWater", title: "water", value: waterText)
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

private struct BeachPin: View {
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
                    .foregroundStyle(Color.risk(risk))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.74), in: .capsule)
                    .zIndex(2)
            }
            VStack(spacing: 2) {
                Image(pinAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(shortName)
                    .font(.custom("Helvetica", size: 14, relativeTo: .caption))
                    .foregroundStyle(Color.jellyInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(width: 91, height: 91)
            .background(showsRadius ? radiusFill : .clear, in: .circle)
            .overlay {
                if selected {
                    Circle().stroke(Color.risk(risk).opacity(0.55), lineWidth: 2)
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
        case .unknown: Color.gray.opacity(0.18)
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

private extension Beach {
    var searchDisplayName: String {
        displayName.replacingOccurrences(of: " Beach", with: "")
    }
}

private struct JellyfishMarker: View {
    let status: String?
    let mock: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let status {
                Text(status).font(.caption2.weight(.bold)).foregroundStyle(Color.jellyCoral)
            } else if mock {
                Text("!").font(.caption.weight(.bold)).foregroundStyle(Color.jellyCoral)
            }
            Image("JellyMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .padding(9)
                .background(Color.jellyCoral.opacity(0.88), in: .circle)
                .overlay { Circle().stroke(Color.jellyCoral.opacity(0.30), lineWidth: 10) }
                .shadow(color: Color.jellyCoral.opacity(0.24), radius: 8)
        }
    }
}
