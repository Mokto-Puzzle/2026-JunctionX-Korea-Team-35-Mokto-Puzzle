import MapKit
import SwiftUI

struct MapPlaygroundView: View {
    @Namespace private var mapScope
    @State private var state = MapPlaygroundState()
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.53, longitude: 129.38),
            span: MKCoordinateSpan(latitudeDelta: 1.25, longitudeDelta: 0.72)
        )
    )
    @State private var isInspectorPresented = true

    private var selectedLocation: JellyfishLocation? {
        state.locations.first { $0.id == state.selectedLocationID }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(
                position: $camera,
                interactionModes: state.interactionModes,
                selection: $state.selectedLocationID,
                scope: mapScope
            ) {
                mapContent
            }
            .mapStyle(state.mapStyle)
            .mapScope(mapScope)
            .ignoresSafeArea()

            mapControls

            VStack(spacing: 10) {
                if let selectedLocation {
                    SelectionCard(location: selectedLocation) {
                        state.selectedLocationID = nil
                    }
                }

                Spacer()

                if !isInspectorPresented {
                    Button {
                        isInspectorPresented = true
                    } label: {
                        Label("지도 설정", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .frame(height: 52)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $isInspectorPresented) {
            MapInspectorView(state: state, camera: $camera)
                .presentationDetents([.height(245), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(28)
        }
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        if state.overlayMode == .risk || state.overlayMode == .all {
            MapPolygon(coordinates: riskPolygon)
                .foregroundStyle(.red.opacity(state.overlayOpacity))
                .stroke(.red.opacity(0.9), lineWidth: 2)
        }

        if state.overlayMode == .radius || state.overlayMode == .all {
            MapCircle(center: state.locations[2].coordinate, radius: 12_000)
                .foregroundStyle(.orange.opacity(state.overlayOpacity))
                .stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        }

        if state.overlayMode == .route || state.overlayMode == .all {
            MapPolyline(coordinates: state.locations.map(\.coordinate))
                .stroke(
                    Gradient(colors: [.mint, .cyan, .orange, .red]),
                    style: StrokeStyle(lineWidth: state.routeWidth, lineCap: .round, lineJoin: .round)
                )
        }

        ForEach(state.locations) { location in
            Annotation(location.name, coordinate: location.coordinate, anchor: .bottom) {
                JellyfishMarker(
                    location: location,
                    scale: state.markerScale,
                    showsLabel: state.showsLabels,
                    showsBackground: state.showsMarkerBackground
                )
            }
            .tag(location.id)
        }
    }

    @ViewBuilder
    private var mapControls: some View {
        VStack(spacing: 8) {
            if state.showsCompass {
                MapCompass(scope: mapScope)
            }
            if state.showsScale {
                MapScaleView(scope: mapScope)
            }
            MapPitchToggle(scope: mapScope)
        }
        .mapControlVisibility(.visible)
        .padding(.top, 12)
        .padding(.trailing, 12)
    }

    private var riskPolygon: [CLLocationCoordinate2D] {
        [
            .init(latitude: 36.23, longitude: 129.33),
            .init(latitude: 36.34, longitude: 129.35),
            .init(latitude: 36.39, longitude: 129.44),
            .init(latitude: 36.27, longitude: 129.47)
        ]
    }
}

private struct JellyfishMarker: View {
    let location: JellyfishLocation
    let scale: Double
    let showsLabel: Bool
    let showsBackground: Bool

    var body: some View {
        VStack(spacing: 5) {
            if showsLabel {
                Text(location.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
            }

            Image(systemName: location.risk.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(showsBackground ? .white : location.risk.color)
                .frame(width: 38, height: 38)
                .background {
                    if showsBackground {
                        Circle().fill(location.risk.color.gradient)
                        Circle().stroke(.white.opacity(0.9), lineWidth: 2)
                    }
                }
                .shadow(color: location.risk.color.opacity(0.35), radius: 8, y: 4)
        }
        .scaleEffect(scale)
        .animation(.snappy, value: scale)
    }
}

private struct SelectionCard: View {
    let location: JellyfishLocation
    let close: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: location.risk.symbol)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(location.risk.color.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(location.name).font(.headline)
                Text("\(location.subtitle) · 출몰 위험 \(location.risk.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("닫기", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.top, 8)
    }
}

private struct MapInspectorView: View {
    @Bindable var state: MapPlaygroundState
    @Binding var camera: MapCameraPosition

    var body: some View {
        NavigationStack {
            Form {
                Section("빠른 프리셋") {
                    Picker("지도", selection: $state.baseStyle) {
                        ForEach(MapPlaygroundState.BaseStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        presetButton("깔끔하게", symbol: "sparkles") {
                            state.baseStyle = .standard
                            state.usesMutedEmphasis = true
                            state.showsPointsOfInterest = false
                            state.showsTraffic = false
                        }
                        presetButton("정보 중심", symbol: "mappin.and.ellipse") {
                            state.baseStyle = .standard
                            state.usesMutedEmphasis = false
                            state.showsPointsOfInterest = true
                            state.showsTraffic = true
                        }
                        presetButton("입체 위성", symbol: "mountain.2") {
                            state.baseStyle = .hybrid
                            state.usesRealisticElevation = true
                            state.showsPointsOfInterest = true
                        }
                    }
                }

                Section("기본 지도") {
                    Toggle("배경을 차분하게", isOn: $state.usesMutedEmphasis)
                        .disabled(state.baseStyle != .standard)
                    Toggle("입체 지형", isOn: $state.usesRealisticElevation)
                    Toggle("관심 장소 표시", isOn: $state.showsPointsOfInterest)
                        .disabled(state.baseStyle == .imagery)
                    Toggle("교통 정보", isOn: $state.showsTraffic)
                        .disabled(state.baseStyle == .imagery)
                }

                Section("데이터 오버레이") {
                    Picker("표시", selection: $state.overlayMode) {
                        ForEach(MapPlaygroundState.OverlayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    LabeledContent("투명도") {
                        Slider(value: $state.overlayOpacity, in: 0.05...0.8)
                            .frame(maxWidth: 190)
                    }
                    LabeledContent("경로 두께") {
                        Slider(value: $state.routeWidth, in: 1...16)
                            .frame(maxWidth: 190)
                    }
                }

                Section("마커") {
                    Toggle("장소 이름", isOn: $state.showsLabels)
                    Toggle("컬러 배경", isOn: $state.showsMarkerBackground)
                    LabeledContent("크기") {
                        Slider(value: $state.markerScale, in: 0.65...1.5)
                            .frame(maxWidth: 190)
                    }
                }

                Section("조작과 기본 컨트롤") {
                    Toggle("지도 이동", isOn: $state.allowsPan)
                    Toggle("확대·축소", isOn: $state.allowsZoom)
                    Toggle("회전", isOn: $state.allowsRotate)
                    Toggle("기울이기", isOn: $state.allowsPitch)
                    Toggle("나침반", isOn: $state.showsCompass)
                    Toggle("축척", isOn: $state.showsScale)
                }

                Section("카메라") {
                    Button("경북 동해안 전체 보기", systemImage: "map") {
                        camera = .region(
                            MKCoordinateRegion(
                                center: .init(latitude: 36.53, longitude: 129.38),
                                span: .init(latitudeDelta: 1.25, longitudeDelta: 0.72)
                            )
                        )
                    }
                    Button("장사해수욕장 3D로 보기", systemImage: "view.3d") {
                        state.usesRealisticElevation = true
                        camera = .camera(
                            MapCamera(
                                centerCoordinate: .init(latitude: 36.2838, longitude: 129.3767),
                                distance: 8_000,
                                heading: 20,
                                pitch: 55
                            )
                        )
                    }
                }
            }
            .navigationTitle("MapKit 디자인 실험실")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("초기화", action: state.reset)
                }
            }
        }
    }

    private func presetButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    MapPlaygroundView()
}
