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
    @State private var selectedMarineSample: MarineSample?

    private let marineSamples = MarineSample.samples

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

                if let selectedMarineSample {
                    MarineDetailCard(sample: selectedMarineSample) {
                        self.selectedMarineSample = nil
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
        if state.marineLayer == .temperature || state.marineLayer == .all {
            ForEach(marineSamples) { sample in
                MapCircle(center: sample.coordinate, radius: 15_000)
                    .foregroundStyle(temperatureColor(sample.temperature).opacity(state.temperatureOpacity))
            }
        }

        if state.marineLayer == .coastalRisk || state.marineLayer == .all {
            MapPolyline(coordinates: coastalRiskLine)
                .stroke(
                    Gradient(colors: [.mint, .yellow, .orange, .red, .orange, .mint]),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                )
        }

        if state.marineLayer == .forecast || state.marineLayer == .all {
            MapPolyline(coordinates: forecastPath)
                .stroke(.purple.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 7]))

            if state.showsForecastUncertainty {
                MapCircle(center: forecastCoordinate, radius: 5_000 + state.forecastHour * 650)
                    .foregroundStyle(.purple.opacity(0.12))
                    .stroke(.purple.opacity(0.65), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }

            Annotation("예상 위치", coordinate: forecastCoordinate) {
                VStack(spacing: 4) {
                    Image(systemName: "aqi.medium")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.purple.gradient, in: Circle())
                    if state.showsMarineValues {
                        Text("+\(Int(state.forecastHour))시간")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
            }
        }

        if state.marineLayer == .current || state.marineLayer == .all {
            ForEach(Array(visibleCurrentSamples.enumerated()), id: \.element.id) { index, sample in
                Annotation("", coordinate: sample.coordinate) {
                    Button {
                        selectedMarineSample = sample
                    } label: {
                        CurrentMarker(
                            sample: sample,
                            scale: state.currentScale,
                            showsValue: state.showsMarineValues,
                            phase: index
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if state.marineLayer == .wave || state.marineLayer == .all {
            ForEach(marineSamples) { sample in
                Annotation("", coordinate: shifted(sample.coordinate, longitude: -0.035)) {
                    Button {
                        selectedMarineSample = sample
                    } label: {
                        WaveMarker(sample: sample, showsValue: state.showsMarineValues)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

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

    private var visibleCurrentSamples: [MarineSample] {
        switch state.currentDensity {
        case 0: return Array(marineSamples.prefix(3))
        case 1: return marineSamples.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? $0.element : nil }
        default: return marineSamples
        }
    }

    private var coastalRiskLine: [CLLocationCoordinate2D] {
        state.locations.map { shifted($0.coordinate, longitude: 0.025) }
    }

    private var forecastPath: [CLLocationCoordinate2D] {
        let origin = CLLocationCoordinate2D(latitude: 36.29, longitude: 129.46)
        return stride(from: 0.0, through: state.forecastHour, by: 3).map { hour in
            .init(latitude: origin.latitude + hour * 0.012, longitude: origin.longitude + hour * 0.006)
        } + [forecastCoordinate]
    }

    private var forecastCoordinate: CLLocationCoordinate2D {
        .init(latitude: 36.29 + state.forecastHour * 0.012, longitude: 129.46 + state.forecastHour * 0.006)
    }

    private func shifted(_ coordinate: CLLocationCoordinate2D, longitude: Double) -> CLLocationCoordinate2D {
        .init(latitude: coordinate.latitude, longitude: coordinate.longitude + longitude)
    }

    private func temperatureColor(_ temperature: Double) -> Color {
        switch state.marinePalette {
        case .thermal:
            if temperature < 24.8 { return .blue }
            if temperature < 26 { return .cyan }
            if temperature < 27 { return .yellow }
            return .red
        case .ocean:
            if temperature < 24.8 { return .indigo }
            if temperature < 26 { return .blue }
            if temperature < 27 { return .cyan }
            return .mint
        case .risk:
            if temperature < 24.8 { return .mint }
            if temperature < 26 { return .yellow }
            if temperature < 27 { return .orange }
            return .red
        }
    }
}

private struct CurrentMarker: View {
    let sample: MarineSample
    let scale: Double
    let showsValue: Bool
    let phase: Int

    @State private var pulses = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 15 + sample.currentSpeed * 12, weight: .bold))
                .foregroundStyle(currentColor)
                .rotationEffect(.degrees(sample.currentDirection))
                .scaleEffect(pulses ? 1.12 : 0.88)
                .shadow(color: .white, radius: 2)
            if showsValue {
                Text(String(format: "%.1f m/s", sample.currentSpeed))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .scaleEffect(scale)
        .task {
            try? await Task.sleep(for: .milliseconds(phase * 90))
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulses = true
            }
        }
    }

    private var currentColor: Color {
        if sample.currentSpeed < 0.5 { return .cyan }
        if sample.currentSpeed < 0.9 { return .blue }
        return .purple
    }
}

private struct WaveMarker: View {
    let sample: MarineSample
    let showsValue: Bool

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "water.waves")
                .font(.system(size: 13 + sample.waveHeight * 7, weight: .semibold))
                .foregroundStyle(sample.waveHeight >= 1.5 ? .orange : .blue)
                .shadow(color: .white, radius: 2)
            if showsValue {
                Text(String(format: "%.1fm", sample.waveHeight))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
        }
    }
}

private struct MarineDetailCard: View {
    let sample: MarineSample
    let close: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "water.waves.and.arrow.trianglehead.up")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.blue.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text("해양 관측 샘플").font(.headline)
                HStack(spacing: 12) {
                    Label(String(format: "%.1f°C", sample.temperature), systemImage: "thermometer.medium")
                    Label(String(format: "%.1fm", sample.waveHeight), systemImage: "water.waves")
                    Label(String(format: "%.1fm/s", sample.currentSpeed), systemImage: "location.north.fill")
                }
                .font(.caption.weight(.medium))
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
                    Toggle("바다 정보 강조", isOn: $state.emphasizesOcean)
                }

                Section("해양 데이터 · 디자인용 샘플") {
                    Picker("레이어", selection: $state.marineLayer) {
                        ForEach(MapPlaygroundState.MarineLayer.allCases) { layer in
                            Text(layer.rawValue).tag(layer)
                        }
                    }

                    Picker("색상", selection: $state.marinePalette) {
                        ForEach(MapPlaygroundState.MarinePalette.allCases) { palette in
                            Text(palette.rawValue).tag(palette)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("수치 표시", isOn: $state.showsMarineValues)
                    Toggle("예측 오차 범위", isOn: $state.showsForecastUncertainty)

                    LabeledContent("예측 시간", value: "+\(Int(state.forecastHour))시간")
                    Slider(value: $state.forecastHour, in: 0...12, step: 3) {
                        Text("예측 시간")
                    } minimumValueLabel: {
                        Text("현재").font(.caption2)
                    } maximumValueLabel: {
                        Text("12h").font(.caption2)
                    }

                    LabeledContent("수온 투명도") {
                        Slider(value: $state.temperatureOpacity, in: 0.1...0.75)
                            .frame(maxWidth: 190)
                    }

                    Picker("해류 밀도", selection: $state.currentDensity) {
                        Text("낮음").tag(0)
                        Text("보통").tag(1)
                        Text("높음").tag(2)
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("해류 크기") {
                        Slider(value: $state.currentScale, in: 0.65...1.6)
                            .frame(maxWidth: 190)
                    }
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
