import MapKit
import SwiftUI

@Observable
final class MapPlaygroundState {
    enum BaseStyle: String, CaseIterable, Identifiable {
        case standard = "기본"
        case hybrid = "하이브리드"
        case imagery = "위성"

        var id: Self { self }
    }

    enum OverlayMode: String, CaseIterable, Identifiable {
        case none = "없음"
        case risk = "위험 구역"
        case radius = "반경"
        case route = "경로"
        case all = "모두"

        var id: Self { self }
    }

    var baseStyle: BaseStyle = .standard
    var usesMutedEmphasis = true
    var usesRealisticElevation = false
    var showsTraffic = false
    var showsPointsOfInterest = true

    var overlayMode: OverlayMode = .all
    var overlayOpacity = 0.28
    var routeWidth = 6.0
    var markerScale = 1.0
    var showsLabels = true
    var showsMarkerBackground = true

    var allowsPan = true
    var allowsZoom = true
    var allowsRotate = true
    var allowsPitch = true
    var showsCompass = true
    var showsScale = false

    var selectedLocationID: JellyfishLocation.ID?

    let locations = JellyfishLocation.samples

    var interactionModes: MapInteractionModes {
        var modes: MapInteractionModes = []
        if allowsPan { modes.insert(.pan) }
        if allowsZoom { modes.insert(.zoom) }
        if allowsRotate { modes.insert(.rotate) }
        if allowsPitch { modes.insert(.pitch) }
        return modes
    }

    var mapStyle: MapStyle {
        let elevation: MapStyle.Elevation = usesRealisticElevation ? .realistic : .flat
        let pointsOfInterest: PointOfInterestCategories = showsPointsOfInterest ? .all : .excludingAll

        switch baseStyle {
        case .standard:
            return .standard(
                elevation: elevation,
                emphasis: usesMutedEmphasis ? .muted : .automatic,
                pointsOfInterest: pointsOfInterest,
                showsTraffic: showsTraffic
            )
        case .hybrid:
            return .hybrid(
                elevation: elevation,
                pointsOfInterest: pointsOfInterest,
                showsTraffic: showsTraffic
            )
        case .imagery:
            return .imagery(elevation: elevation)
        }
    }

    func reset() {
        baseStyle = .standard
        usesMutedEmphasis = true
        usesRealisticElevation = false
        showsTraffic = false
        showsPointsOfInterest = true
        overlayMode = .all
        overlayOpacity = 0.28
        routeWidth = 6
        markerScale = 1
        showsLabels = true
        showsMarkerBackground = true
        allowsPan = true
        allowsZoom = true
        allowsRotate = true
        allowsPitch = true
        showsCompass = true
        showsScale = false
    }
}

struct JellyfishLocation: Identifiable, Hashable {
    enum Risk: String, CaseIterable {
        case low = "낮음"
        case medium = "주의"
        case high = "높음"

        var color: Color {
            switch self {
            case .low: .mint
            case .medium: .orange
            case .high: .red
            }
        }

        var symbol: String {
            switch self {
            case .low: "checkmark"
            case .medium: "exclamationmark"
            case .high: "exclamationmark.triangle.fill"
            }
        }
    }

    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let risk: Risk

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let samples: [Self] = [
        .init(name: "영일대해수욕장", subtitle: "포항", coordinate: .init(latitude: 36.0572, longitude: 129.3780), risk: .medium),
        .init(name: "월포해수욕장", subtitle: "포항", coordinate: .init(latitude: 36.2038, longitude: 129.3716), risk: .low),
        .init(name: "장사해수욕장", subtitle: "영덕", coordinate: .init(latitude: 36.2838, longitude: 129.3767), risk: .high),
        .init(name: "고래불해수욕장", subtitle: "영덕", coordinate: .init(latitude: 36.5996, longitude: 129.4111), risk: .medium),
        .init(name: "망양정해수욕장", subtitle: "울진", coordinate: .init(latitude: 36.9900, longitude: 129.4147), risk: .low)
    ]
}
