import CoreLocation
import SwiftUI

enum BeachSafety: String, CaseIterable, Identifiable {
    case calm = "Safe"
    case caution = "Caution"
    case danger = "High Risk"
    case unknown = "Check Status"

    var id: Self { self }
    var color: Color {
        switch self {
        case .calm: .mint
        case .caution: .orange
        case .danger: .red
        case .unknown: .gray
        }
    }
    var symbol: String {
        switch self {
        case .calm: "checkmark"
        case .caution: "exclamationmark"
        case .danger: "exclamationmark.triangle.fill"
        case .unknown: "questionmark"
        }
    }
    var rank: Int {
        switch self {
        case .calm: 0
        case .caution: 1
        case .unknown: 2
        case .danger: 3
        }
    }
}

struct Beach: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let region: String
    let coordinate: CLLocationCoordinate2D
    let safety: BeachSafety
    let summary: String
    let distance: Int
    let temperature: Double
    let wave: Double
    let current: Double
    let sightings: Int
    let updatedMinutes: Int
    let bestTime: String

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let samples: [Self] = [
        .init(name: "Wolpo Beach", region: "Pohang", coordinate: .init(latitude: 36.2038, longitude: 129.3716), safety: .calm, summary: "Few recent sightings and the current is moving away from shore.", distance: 24, temperature: 25.3, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 18, bestTime: "Before 4 PM"),
        .init(name: "Yeongildae Beach", region: "Pohang", coordinate: .init(latitude: 36.0572, longitude: 129.3780), safety: .caution, summary: "Southern sightings suggest extra caution this afternoon.", distance: 12, temperature: 26.4, wave: 0.9, current: 0.6, sightings: 2, updatedMinutes: 24, bestTime: "Before 1 PM"),
        .init(name: "Jangsa Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.2838, longitude: 129.3767), safety: .danger, summary: "Recent sightings and an onshore current were both detected.", distance: 39, temperature: 27.2, wave: 1.6, current: 0.9, sightings: 8, updatedMinutes: 10, bestTime: "Not recommended today"),
        .init(name: "Goraebul Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.5996, longitude: 129.4111), safety: .caution, summary: "Conditions are moderate now, with possible inflow this evening.", distance: 57, temperature: 25.9, wave: 1.2, current: 0.7, sightings: 2, updatedMinutes: 42, bestTime: "Before 3 PM"),
        .init(name: "Mangyangjeong Beach", region: "Uljin", coordinate: .init(latitude: 36.9900, longitude: 129.4147), safety: .unknown, summary: "Recent observations are limited. Check conditions on site.", distance: 81, temperature: 24.3, wave: 0.7, current: 0.4, sightings: 0, updatedMinutes: 130, bestTime: "After checking updates"),
        .init(name: "Guryongpo Beach", region: "Pohang", coordinate: .init(latitude: 35.997, longitude: 129.566), safety: .calm, summary: "Currently outside the predicted movement zone.", distance: 28, temperature: 25.8, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 31, bestTime: "Before 5 PM"),
        .init(name: "Dogu Beach", region: "Pohang", coordinate: .init(latitude: 35.933, longitude: 129.442), safety: .caution, summary: "The onshore current may strengthen this afternoon.", distance: 18, temperature: 26.1, wave: 1.0, current: 0.6, sightings: 1, updatedMinutes: 38, bestTime: "Before 2 PM"),
        .init(name: "Sinchang Beach", region: "Pohang", coordinate: .init(latitude: 35.841, longitude: 129.528), safety: .calm, summary: "No recent sightings and low waves.", distance: 37, temperature: 25.5, wave: 0.5, current: 0.3, sightings: 0, updatedMinutes: 27, bestTime: "All day"),
        .init(name: "Songdo Beach", region: "Pohang", coordinate: .init(latitude: 36.033, longitude: 129.378), safety: .caution, summary: "Check recent observation records along the urban coast.", distance: 10, temperature: 26.5, wave: 0.7, current: 0.5, sightings: 2, updatedMinutes: 22, bestTime: "Before 1 PM"),
        .init(name: "Chilpo Beach", region: "Pohang", coordinate: .init(latitude: 36.154, longitude: 129.402), safety: .calm, summary: "The predicted movement zone remains offshore.", distance: 21, temperature: 25.6, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 34, bestTime: "Before 5 PM"),
        .init(name: "Hwajin Beach", region: "Pohang", coordinate: .init(latitude: 36.256, longitude: 129.372), safety: .caution, summary: "Northeast current changes are being monitored.", distance: 32, temperature: 25.7, wave: 1.1, current: 0.7, sightings: 1, updatedMinutes: 45, bestTime: "Before 2 PM"),
        .init(name: "Oryu Goara Beach", region: "Gyeongju", coordinate: .init(latitude: 35.817, longitude: 129.516), safety: .calm, summary: "No direct sightings have been reported recently.", distance: 43, temperature: 25.4, wave: 0.7, current: 0.3, sightings: 0, updatedMinutes: 29, bestTime: "All day"),
        .init(name: "Najeong Gounmorae Beach", region: "Gyeongju", coordinate: .init(latitude: 35.783, longitude: 129.494), safety: .caution, summary: "The water temperature is near the preferred activity range.", distance: 48, temperature: 26.6, wave: 0.9, current: 0.5, sightings: 1, updatedMinutes: 37, bestTime: "Before 3 PM"),
        .init(name: "Bonggil Daewangam Beach", region: "Gyeongju", coordinate: .init(latitude: 35.738, longitude: 129.485), safety: .danger, summary: "Close to the predicted route of a southern sighting cluster.", distance: 55, temperature: 27.0, wave: 1.4, current: 0.8, sightings: 5, updatedMinutes: 16, bestTime: "Not recommended today"),
        .init(name: "Gwanseong Solbat Beach", region: "Gyeongju", coordinate: .init(latitude: 35.663, longitude: 129.451), safety: .calm, summary: "Few recent sightings and a weak current.", distance: 66, temperature: 25.2, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 52, bestTime: "Before 5 PM"),
        .init(name: "Namho Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.337, longitude: 129.381), safety: .caution, summary: "Located near the edge of the predicted route.", distance: 44, temperature: 26.0, wave: 1.0, current: 0.6, sightings: 1, updatedMinutes: 33, bestTime: "Before 2 PM"),
        .init(name: "Hajeo Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.390, longitude: 129.414), safety: .calm, summary: "No direct sightings at this time.", distance: 48, temperature: 25.5, wave: 0.7, current: 0.4, sightings: 0, updatedMinutes: 41, bestTime: "Before 4 PM"),
        .init(name: "Obo Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.444, longitude: 129.430), safety: .caution, summary: "Possible inflow during the evening.", distance: 51, temperature: 26.2, wave: 1.1, current: 0.7, sightings: 2, updatedMinutes: 25, bestTime: "Before 2 PM"),
        .init(name: "Gyeongjeong Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.486, longitude: 129.440), safety: .danger, summary: "Recent sightings and a strong current were detected.", distance: 54, temperature: 26.8, wave: 1.5, current: 0.9, sightings: 6, updatedMinutes: 14, bestTime: "Not recommended today"),
        .init(name: "Daejin Beach", region: "Yeongdeok", coordinate: .init(latitude: 36.558, longitude: 129.426), safety: .calm, summary: "Current sightings remain far from the predicted route.", distance: 59, temperature: 25.3, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 36, bestTime: "Before 5 PM"),
        .init(name: "Nagok Beach", region: "Uljin", coordinate: .init(latitude: 37.119, longitude: 129.376), safety: .calm, summary: "The northern waters are relatively stable.", distance: 96, temperature: 23.8, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 48, bestTime: "Before 5 PM"),
        .init(name: "Hujeong Beach", region: "Uljin", coordinate: .init(latitude: 37.075, longitude: 129.413), safety: .calm, summary: "No recent sightings and cooler water.", distance: 90, temperature: 24.0, wave: 0.7, current: 0.3, sightings: 0, updatedMinutes: 43, bestTime: "All day"),
        .init(name: "Gusan Beach", region: "Uljin", coordinate: .init(latitude: 36.755, longitude: 129.471), safety: .caution, summary: "Check the current direction this afternoon.", distance: 72, temperature: 25.5, wave: 1.0, current: 0.6, sightings: 1, updatedMinutes: 39, bestTime: "Before 3 PM"),
        .init(name: "Hupo Beach", region: "Uljin", coordinate: .init(latitude: 36.676, longitude: 129.453), safety: .calm, summary: "Currently outside the predicted movement zone.", distance: 65, temperature: 25.1, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 32, bestTime: "Before 5 PM")
    ]
}

struct HourlySafety: Identifiable {
    let id = UUID()
    let time: String
    let safety: BeachSafety
    let reason: String
}
