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
        .init(name: "월포해수욕장", region: "포항", coordinate: .init(latitude: 36.2038, longitude: 129.3716), safety: .calm, summary: "최근 관측이 적고 해류가 연안 반대 방향이에요.", distance: 24, temperature: 25.3, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 18, bestTime: "오늘 16시 이전"),
        .init(name: "영일대해수욕장", region: "포항", coordinate: .init(latitude: 36.0572, longitude: 129.3780), safety: .caution, summary: "남쪽 해역 관측으로 오후에는 주의가 필요해요.", distance: 12, temperature: 26.4, wave: 0.9, current: 0.6, sightings: 2, updatedMinutes: 24, bestTime: "오늘 13시 이전"),
        .init(name: "장사해수욕장", region: "영덕", coordinate: .init(latitude: 36.2838, longitude: 129.3767), safety: .danger, summary: "최근 관측과 연안 방향 해류가 함께 확인됐어요.", distance: 39, temperature: 27.2, wave: 1.6, current: 0.9, sightings: 8, updatedMinutes: 10, bestTime: "오늘은 권하지 않아요"),
        .init(name: "고래불해수욕장", region: "영덕", coordinate: .init(latitude: 36.5996, longitude: 129.4111), safety: .caution, summary: "현재는 보통이지만 저녁 유입 가능성이 있어요.", distance: 57, temperature: 25.9, wave: 1.2, current: 0.7, sightings: 2, updatedMinutes: 42, bestTime: "오늘 15시 이전"),
        .init(name: "망양정해수욕장", region: "울진", coordinate: .init(latitude: 36.9900, longitude: 129.4147), safety: .unknown, summary: "최신 관측이 부족해 현장 확인이 필요해요.", distance: 81, temperature: 24.3, wave: 0.7, current: 0.4, sightings: 0, updatedMinutes: 130, bestTime: "최신 정보 확인 후"),
        .init(name: "구룡포해수욕장", region: "포항", coordinate: .init(latitude: 35.997, longitude: 129.566), safety: .calm, summary: "현재 예상 이동 범위에서 벗어나 있어요.", distance: 28, temperature: 25.8, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 31, bestTime: "오늘 17시 이전"),
        .init(name: "도구해수욕장", region: "포항", coordinate: .init(latitude: 35.933, longitude: 129.442), safety: .caution, summary: "오후에 연안 방향 해류가 강해질 수 있어요.", distance: 18, temperature: 26.1, wave: 1.0, current: 0.6, sightings: 1, updatedMinutes: 38, bestTime: "오늘 14시 이전"),
        .init(name: "신창해수욕장", region: "포항", coordinate: .init(latitude: 35.841, longitude: 129.528), safety: .calm, summary: "최근 관측이 없고 파고가 낮아요.", distance: 37, temperature: 25.5, wave: 0.5, current: 0.3, sightings: 0, updatedMinutes: 27, bestTime: "오늘 하루"),
        .init(name: "송도해수욕장", region: "포항", coordinate: .init(latitude: 36.033, longitude: 129.378), safety: .caution, summary: "도심 연안 관측 기록을 확인해 주세요.", distance: 10, temperature: 26.5, wave: 0.7, current: 0.5, sightings: 2, updatedMinutes: 22, bestTime: "오늘 13시 이전"),
        .init(name: "칠포해수욕장", region: "포항", coordinate: .init(latitude: 36.154, longitude: 129.402), safety: .calm, summary: "예상 이동 범위와 거리가 있어요.", distance: 21, temperature: 25.6, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 34, bestTime: "오늘 17시 이전"),
        .init(name: "화진해수욕장", region: "포항", coordinate: .init(latitude: 36.256, longitude: 129.372), safety: .caution, summary: "북동향 해류 변화를 관찰 중이에요.", distance: 32, temperature: 25.7, wave: 1.1, current: 0.7, sightings: 1, updatedMinutes: 45, bestTime: "오늘 14시 이전"),
        .init(name: "오류고아라해변", region: "경주", coordinate: .init(latitude: 35.817, longitude: 129.516), safety: .calm, summary: "현재 직접 관측 기록이 없어요.", distance: 43, temperature: 25.4, wave: 0.7, current: 0.3, sightings: 0, updatedMinutes: 29, bestTime: "오늘 하루"),
        .init(name: "나정고운모래해변", region: "경주", coordinate: .init(latitude: 35.783, longitude: 129.494), safety: .caution, summary: "수온이 활동 적합 범위에 가까워요.", distance: 48, temperature: 26.6, wave: 0.9, current: 0.5, sightings: 1, updatedMinutes: 37, bestTime: "오늘 15시 이전"),
        .init(name: "봉길대왕암해변", region: "경주", coordinate: .init(latitude: 35.738, longitude: 129.485), safety: .danger, summary: "남쪽 관측 군집의 예상 경로와 가까워요.", distance: 55, temperature: 27.0, wave: 1.4, current: 0.8, sightings: 5, updatedMinutes: 16, bestTime: "오늘은 권하지 않아요"),
        .init(name: "관성솔밭해변", region: "경주", coordinate: .init(latitude: 35.663, longitude: 129.451), safety: .calm, summary: "최근 관측이 적고 해류가 약해요.", distance: 66, temperature: 25.2, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 52, bestTime: "오늘 17시 이전"),
        .init(name: "남호해수욕장", region: "영덕", coordinate: .init(latitude: 36.337, longitude: 129.381), safety: .caution, summary: "예상 경로 가장자리에 위치해요.", distance: 44, temperature: 26.0, wave: 1.0, current: 0.6, sightings: 1, updatedMinutes: 33, bestTime: "오늘 14시 이전"),
        .init(name: "하저해수욕장", region: "영덕", coordinate: .init(latitude: 36.390, longitude: 129.414), safety: .calm, summary: "현재 직접 관측은 없어요.", distance: 48, temperature: 25.5, wave: 0.7, current: 0.4, sightings: 0, updatedMinutes: 41, bestTime: "오늘 16시 이전"),
        .init(name: "오보해수욕장", region: "영덕", coordinate: .init(latitude: 36.444, longitude: 129.430), safety: .caution, summary: "저녁 시간 유입 가능성이 있어요.", distance: 51, temperature: 26.2, wave: 1.1, current: 0.7, sightings: 2, updatedMinutes: 25, bestTime: "오늘 14시 이전"),
        .init(name: "경정해수욕장", region: "영덕", coordinate: .init(latitude: 36.486, longitude: 129.440), safety: .danger, summary: "최근 관측과 강한 해류가 확인됐어요.", distance: 54, temperature: 26.8, wave: 1.5, current: 0.9, sightings: 6, updatedMinutes: 14, bestTime: "오늘은 권하지 않아요"),
        .init(name: "대진해수욕장", region: "영덕", coordinate: .init(latitude: 36.558, longitude: 129.426), safety: .calm, summary: "현재 관측과 예상 경로가 멀어요.", distance: 59, temperature: 25.3, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 36, bestTime: "오늘 17시 이전"),
        .init(name: "나곡해수욕장", region: "울진", coordinate: .init(latitude: 37.119, longitude: 129.376), safety: .calm, summary: "북부 해역은 현재 비교적 안정적이에요.", distance: 96, temperature: 23.8, wave: 0.6, current: 0.3, sightings: 0, updatedMinutes: 48, bestTime: "오늘 17시 이전"),
        .init(name: "후정해수욕장", region: "울진", coordinate: .init(latitude: 37.075, longitude: 129.413), safety: .calm, summary: "최근 관측이 없고 수온이 낮아요.", distance: 90, temperature: 24.0, wave: 0.7, current: 0.3, sightings: 0, updatedMinutes: 43, bestTime: "오늘 하루"),
        .init(name: "구산해수욕장", region: "울진", coordinate: .init(latitude: 36.755, longitude: 129.471), safety: .caution, summary: "오후 해류 방향을 확인해 주세요.", distance: 72, temperature: 25.5, wave: 1.0, current: 0.6, sightings: 1, updatedMinutes: 39, bestTime: "오늘 15시 이전"),
        .init(name: "후포해수욕장", region: "울진", coordinate: .init(latitude: 36.676, longitude: 129.453), safety: .calm, summary: "현재 예상 이동 범위에서 벗어나 있어요.", distance: 65, temperature: 25.1, wave: 0.8, current: 0.4, sightings: 0, updatedMinutes: 32, bestTime: "오늘 17시 이전")
    ]
}

struct HourlySafety: Identifiable {
    let id = UUID()
    let time: String
    let safety: BeachSafety
    let reason: String
}
