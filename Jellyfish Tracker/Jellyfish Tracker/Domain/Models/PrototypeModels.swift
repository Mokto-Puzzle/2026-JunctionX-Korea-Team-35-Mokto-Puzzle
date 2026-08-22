import CoreLocation
import SwiftUI

enum BeachSafety: String, CaseIterable, Identifiable {
    case calm = "안심"
    case caution = "주의"
    case danger = "위험"
    case unknown = "확인 필요"

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
        .init(name: "월포해수욕장", region: "포항", coordinate: .init(latitude: 36.2038, longitude: 129.3716), safety: .calm, summary: "최근 관측이 적고 해류가 연안 반대 방향이에요.", distance: 24, temperature: 25.3, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 18, bestTime: "오늘 16시 이전"),
        .init(name: "영일대해수욕장", region: "포항", coordinate: .init(latitude: 36.0572, longitude: 129.3780), safety: .caution, summary: "남쪽 해역 관측으로 오후에는 주의가 필요해요.", distance: 12, temperature: 26.4, wave: 0.9, current: 0.6, sightings: 2, updatedMinutes: 24, bestTime: "오늘 13시 이전"),
        .init(name: "장사해수욕장", region: "영덕", coordinate: .init(latitude: 36.2838, longitude: 129.3767), safety: .danger, summary: "최근 관측과 연안 방향 해류가 함께 확인됐어요.", distance: 39, temperature: 27.2, wave: 1.6, current: 0.9, sightings: 8, updatedMinutes: 10, bestTime: "오늘은 권하지 않아요"),
        .init(name: "고래불해수욕장", region: "영덕", coordinate: .init(latitude: 36.5996, longitude: 129.4111), safety: .caution, summary: "현재는 보통이지만 저녁 유입 가능성이 있어요.", distance: 57, temperature: 25.9, wave: 1.2, current: 0.7, sightings: 2, updatedMinutes: 42, bestTime: "오늘 15시 이전"),
        .init(name: "망양정해수욕장", region: "울진", coordinate: .init(latitude: 36.9900, longitude: 129.4147), safety: .unknown, summary: "최신 관측이 부족해 현장 확인이 필요해요.", distance: 81, temperature: 24.3, wave: 0.7, current: 0.4, sightings: 0, updatedMinutes: 130, bestTime: "최신 정보 확인 후")
    ]
}

struct HourlySafety: Identifiable {
    let id = UUID()
    let time: String
    let safety: BeachSafety
    let reason: String
}
