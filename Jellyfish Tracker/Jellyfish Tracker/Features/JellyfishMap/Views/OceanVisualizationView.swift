import MapKit
import SwiftUI

enum OceanDisplayLayer: String, CaseIterable, Identifiable, Hashable {
    case forecast = "예상 이동 경로"
    case current = "해류"
    case temperature = "수온"
    var id: Self { self }
}

struct OceanVisualizationView: View {
    let layers: Set<OceanDisplayLayer>
    let forecastHour: Double
    let beaches: [Beach]
    let onSelectBeach: (Beach) -> Void

    @State private var camera: MapCameraPosition = .region(Self.eastCoastRegion)

    private static let eastCoastRegion = MKCoordinateRegion(
        center: .init(latitude: 36.32, longitude: 129.42),
        span: .init(latitudeDelta: 1.55, longitudeDelta: 0.72)
    )

    var body: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
            if layers.contains(.temperature) {
                ForEach(Beach.samples) { beach in
                    MapCircle(center: shifted(beach.coordinate, longitude: 0.055), radius: 12_000)
                        .foregroundStyle(temperatureColor(beach.temperature).opacity(0.28))
                        .stroke(temperatureColor(beach.temperature).opacity(0.45), lineWidth: 1)
                }
            }

            if layers.contains(.forecast) {
                MapPolyline(coordinates: forecastPath)
                    .stroke(.purple, style: .init(lineWidth: 6, lineCap: .round, dash: [9, 7]))
                MapCircle(center: forecastCoordinate, radius: max(4_000, 7_000 + forecastHour * 250))
                    .foregroundStyle(.purple.opacity(0.18))
                    .stroke(.purple.opacity(0.8), style: .init(lineWidth: 2, dash: [6, 5]))
                Annotation("예상 위치", coordinate: forecastCoordinate) {
                    VStack(spacing: 3) {
                        Image(systemName: "aqi.medium").font(.title2.bold()).foregroundStyle(.white)
                            .frame(width: 42, height: 42).background(.purple.gradient, in: Circle())
                        Text(forecastTimeLabel).font(.caption2.bold())
                            .padding(.horizontal, 7).padding(.vertical, 3).background(.regularMaterial, in: Capsule())
                    }
                }
            }

            if layers.contains(.current) {
                ForEach(Array(Beach.samples.enumerated()), id: \.element.id) { index, beach in
                    Annotation("", coordinate: shifted(beach.coordinate, longitude: 0.09)) {
                        VStack(spacing: 1) {
                            Image(systemName: "location.north.fill")
                                .font(.title3.bold()).foregroundStyle(.cyan)
                                .rotationEffect(.degrees(Double((index * 23) % 100 - 35)))
                            Text(String(format: "%.1fm/s", beach.current)).font(.caption2.bold())
                                .foregroundStyle(.white).padding(.horizontal, 4).background(.black.opacity(0.55), in: Capsule())
                        }
                    }
                }
            }

            ForEach(beaches) { beach in
                Annotation(beach.name, coordinate: beach.coordinate, anchor: .bottom) {
                    Button { onSelectBeach(beach) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: beach.safety.symbol).font(.headline.bold()).foregroundStyle(.white)
                                .frame(width: 42, height: 42).background(beach.safety.color.gradient, in: Circle())
                                .overlay(Circle().stroke(beach.id == Beach.samples[0].id ? .cyan : .white, lineWidth: beach.id == Beach.samples[0].id ? 4 : 2))
                                .shadow(radius: 4, y: 2)
                            Text(beach.id == Beach.samples[0].id ? "추천" : beach.name.replacingOccurrences(of: "해수욕장", with: ""))
                                .font(.caption2.bold()).foregroundStyle(beach.id == Beach.samples[0].id ? .cyan : .primary)
                                .padding(.horizontal, 6).padding(.vertical, 3).background(.regularMaterial, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls { MapCompass(); MapScaleView() }
        .onAppear { fitCamera(to: beaches) }
        .onChange(of: beaches.map(\.id)) { _, _ in fitCamera(to: beaches) }
    }

    private var forecastCoordinate: CLLocationCoordinate2D {
        .init(latitude: 36.20 + forecastHour * 0.018, longitude: 129.54 + forecastHour * 0.006)
    }

    private var forecastTimeLabel: String {
        forecastHour == 0 ? "현재 위치" : forecastHour > 0 ? "+\(Int(forecastHour))시간 예상" : "\(abs(Int(forecastHour)))시간 전 기록"
    }

    private var forecastPath: [CLLocationCoordinate2D] {
        [.init(latitude: 36.12, longitude: 129.61), .init(latitude: 36.19, longitude: 129.56), forecastCoordinate]
    }

    private func fitCamera(to beaches: [Beach]) {
        guard !beaches.isEmpty else { camera = .region(Self.eastCoastRegion); return }
        let latitudes = beaches.map(\.coordinate.latitude)
        let longitudes = beaches.map(\.coordinate.longitude)
        let minLatitude = latitudes.min()!, maxLatitude = latitudes.max()!
        let minLongitude = longitudes.min()!, maxLongitude = longitudes.max()!
        let region = MKCoordinateRegion(
            center: .init(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2 + 0.08),
            span: .init(
                latitudeDelta: max((maxLatitude - minLatitude) * 1.65, beaches.count == 1 ? 0.12 : 0.26),
                longitudeDelta: max((maxLongitude - minLongitude) * 1.8, beaches.count == 1 ? 0.15 : 0.34)
            )
        )
        withAnimation(.easeInOut(duration: 0.65)) { camera = .region(region) }
    }

    private func shifted(_ coordinate: CLLocationCoordinate2D, longitude: Double) -> CLLocationCoordinate2D {
        .init(latitude: coordinate.latitude, longitude: coordinate.longitude + longitude)
    }

    private func temperatureColor(_ temperature: Double) -> Color {
        temperature >= 27 ? .red : temperature >= 26 ? .orange : temperature >= 25 ? .yellow : .blue
    }
}
