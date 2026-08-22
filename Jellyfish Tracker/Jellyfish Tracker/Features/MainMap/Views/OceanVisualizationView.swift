import MapKit
import SwiftUI

enum OceanDisplayLayer: String, CaseIterable, Identifiable, Hashable {
    case forecast = "Predicted Route"
    case current = "Current"
    case temperature = "Water Temperature"
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
                    .stroke(Color.brandTeal.opacity(0.7), style: .init(lineWidth: 3, lineCap: .round))
                MapCircle(center: forecastCoordinate, radius: max(4_000, 7_000 + forecastHour * 250))
                    .foregroundStyle(Color.brandTeal.opacity(0.08))
                    .stroke(Color.brandTeal.opacity(0.45), style: .init(lineWidth: 1.5, dash: [5, 5]))
                Annotation("", coordinate: forecastCoordinate) {
                    VStack(spacing: 3) {
                        JellyfishGlyph().fill(Color.brandTeal).frame(width: 46, height: 46)
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
                Annotation("", coordinate: beach.coordinate, anchor: .bottom) {
                    Button { onSelectBeach(beach) } label: {
                        BeachMapMarker(beach: beach, isRecommended: beach.id == recommendedID)
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
        forecastHour == 0 ? "Current position" : forecastHour > 0 ? "+\(Int(forecastHour))h forecast" : "\(abs(Int(forecastHour)))h ago"
    }

    private var forecastPath: [CLLocationCoordinate2D] {
        [.init(latitude: 36.12, longitude: 129.61), .init(latitude: 36.19, longitude: 129.56), forecastCoordinate]
    }

    private var recommendedID: Beach.ID? {
        beaches.sorted {
            if $0.safety.rank != $1.safety.rank { return $0.safety.rank < $1.safety.rank }
            if $0.sightings != $1.sightings { return $0.sightings < $1.sightings }
            return $0.distance < $1.distance
        }.first?.id
    }

    private func fitCamera(to beaches: [Beach]) {
        guard !beaches.isEmpty else { camera = .region(Self.eastCoastRegion); return }
        let latitudes = beaches.map(\.coordinate.latitude)
        let longitudes = beaches.map(\.coordinate.longitude)
        let minLatitude = latitudes.min()!, maxLatitude = latitudes.max()!
        let minLongitude = longitudes.min()!, maxLongitude = longitudes.max()!
        let latitudeDelta = max((maxLatitude - minLatitude) * 1.65, beaches.count == 1 ? 0.12 : 0.26)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.8, beaches.count == 1 ? 0.15 : 0.34)
        let region = MKCoordinateRegion(
            center: .init(
                latitude: (minLatitude + maxLatitude) / 2 + latitudeDelta * 0.18,
                longitude: (minLongitude + maxLongitude) / 2 + 0.08
            ),
            span: .init(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
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

private struct BeachMapMarker: View {
    let beach: Beach
    let isRecommended: Bool

    var body: some View {
        VStack(spacing: -3) {
            Text(String(format: "%.1f°C", beach.temperature))
                .font(.caption.bold()).foregroundStyle(temperatureColor)
                .padding(.horizontal, 8).padding(.vertical, 5).background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            ZStack {
                Circle().fill(temperatureColor.opacity(0.22)).frame(width: isRecommended ? 86 : 72, height: isRecommended ? 86 : 72)
                VStack(spacing: 2) {
                    Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(temperatureColor)
                    Text(beach.name.replacingOccurrences(of: " Beach", with: ""))
                        .font(.caption2).foregroundStyle(.primary).lineLimit(1)
                }
            }
        }
    }

    private var temperatureColor: Color {
        beach.temperature >= 27 ? .red : beach.temperature >= 26 ? .orange : beach.temperature >= 25 ? .brandTeal : .cyan
    }
}
