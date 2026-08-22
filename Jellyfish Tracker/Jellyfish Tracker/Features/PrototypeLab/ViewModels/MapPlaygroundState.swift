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

    enum MarineLayer: String, CaseIterable, Identifiable {
        case none = "없음"
        case temperature = "수온"
        case current = "해류"
        case wave = "파고"
        case forecast = "예측"
        case coastalRisk = "연안 위험"
        case all = "종합"

        var id: Self { self }
    }

    enum MarinePalette: String, CaseIterable, Identifiable {
        case thermal = "수온"
        case ocean = "오션"
        case risk = "위험도"

        var id: Self { self }
    }

    var baseStyle: BaseStyle = .standard
    var usesMutedEmphasis = true
    var usesRealisticElevation = false
    var showsTraffic = false
    var showsPointsOfInterest = true

    var overlayMode: OverlayMode = .none
    var overlayOpacity = 0.28
    var routeWidth = 6.0
    var markerScale = 1.0
    var showsLabels = true
    var showsMarkerBackground = true

    var marineLayer: MarineLayer = .all
    var marinePalette: MarinePalette = .thermal
    var forecastHour = 0.0
    var temperatureOpacity = 0.30
    var currentDensity = 1
    var currentScale = 1.0
    var showsMarineValues = true
    var showsForecastUncertainty = true
    var emphasizesOcean = false

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
        let pointsOfInterest: PointOfInterestCategories = (showsPointsOfInterest && !emphasizesOcean) ? .all : .excludingAll

        switch baseStyle {
        case .standard:
            return .standard(
                elevation: elevation,
                emphasis: (usesMutedEmphasis || emphasizesOcean) ? .muted : .automatic,
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
        overlayMode = .none
        overlayOpacity = 0.28
        routeWidth = 6
        markerScale = 1
        showsLabels = true
        showsMarkerBackground = true
        marineLayer = .all
        marinePalette = .thermal
        forecastHour = 0
        temperatureOpacity = 0.30
        currentDensity = 1
        currentScale = 1
        showsMarineValues = true
        showsForecastUncertainty = true
        emphasizesOcean = false
        allowsPan = true
        allowsZoom = true
        allowsRotate = true
        allowsPitch = true
        showsCompass = true
        showsScale = false
    }
}

struct MarineSample: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let temperature: Double
    let currentSpeed: Double
    let currentDirection: Double
    let waveHeight: Double

    static let samples: [Self] = [
        .init(coordinate: .init(latitude: 36.08, longitude: 129.46), temperature: 25.8, currentSpeed: 0.35, currentDirection: 15, waveHeight: 0.6),
        .init(coordinate: .init(latitude: 36.22, longitude: 129.47), temperature: 26.4, currentSpeed: 0.62, currentDirection: 28, waveHeight: 0.9),
        .init(coordinate: .init(latitude: 36.36, longitude: 129.48), temperature: 27.2, currentSpeed: 0.91, currentDirection: 42, waveHeight: 1.6),
        .init(coordinate: .init(latitude: 36.52, longitude: 129.50), temperature: 26.7, currentSpeed: 0.74, currentDirection: 25, waveHeight: 1.2),
        .init(coordinate: .init(latitude: 36.68, longitude: 129.51), temperature: 25.3, currentSpeed: 0.48, currentDirection: 350, waveHeight: 0.8),
        .init(coordinate: .init(latitude: 36.84, longitude: 129.52), temperature: 24.6, currentSpeed: 0.29, currentDirection: 330, waveHeight: 0.5),
        .init(coordinate: .init(latitude: 36.98, longitude: 129.53), temperature: 24.1, currentSpeed: 0.41, currentDirection: 345, waveHeight: 0.7),
        .init(coordinate: .init(latitude: 36.30, longitude: 129.62), temperature: 26.9, currentSpeed: 1.08, currentDirection: 55, waveHeight: 2.1),
        .init(coordinate: .init(latitude: 36.58, longitude: 129.65), temperature: 25.9, currentSpeed: 0.86, currentDirection: 35, waveHeight: 1.7),
        .init(coordinate: .init(latitude: 36.88, longitude: 129.66), temperature: 24.8, currentSpeed: 0.57, currentDirection: 10, waveHeight: 1.0)
    ]
}

struct JellyfishLocation: Identifiable, Hashable {
    enum Risk: String, CaseIterable {
        case low = "낮음"
        case medium = "주의"
        case high = "높음"

        var color: Color {
            switch self {
            case .low: AppColor.Prototype.mint
            case .medium: AppColor.Prototype.orange
            case .high: AppColor.Prototype.red
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
