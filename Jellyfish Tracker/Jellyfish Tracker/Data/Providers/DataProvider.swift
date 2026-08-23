import Foundation
import CoreLocation

protocol OceanDataProviding {
    var sourceLabel: String { get }
    var predictionUsesMockData: Bool { get }
    func fetchBeaches() async throws -> [Beach]
    func fetchTracks() async throws -> [JellyfishTrack]
}

struct MockOceanDataProvider: OceanDataProviding {
    let sourceLabel = "REFERENCE DATA"
    let predictionUsesMockData = true
    func fetchBeaches() async throws -> [Beach] { Self.beaches }
    func fetchTracks() async throws -> [JellyfishTrack] { Self.modeledTracks }

    private static func beach(
        _ id: String, _ name: String, _ city: String, _ lat: Double, _ lon: Double,
        risk: RiskLevel, recent: Bool, water: Double, wave: Double, wind: Double,
        summary: String, facilities: [String] = ["주차", "샤워장", "화장실"]
    ) -> Beach {
        let activities: [ActivityGroup: RiskLevel] = [
            .calmWater: wave < 0.9 ? risk : max(risk, .caution),
            .board: wave > 0.7 && wave < 1.8 ? risk : .caution,
            .offshore: wind < 7 ? risk : .later
        ]
        return Beach(
            id: id, name: name, city: city, latitude: lat, longitude: lon,
            summary: summary, address: "경상북도 \(city) \(name)", facilities: facilities,
            recentJellyfish: recent,
            lastObservation: recent ? "어제 연안 6km 지점 관측" : "최근 7일 관측 없음",
            species: recent ? "노무라입깃해파리" : "관측 정보 없음",
            toxicity: recent ? "강함" : "-", baseRisk: risk,
            marine: MarineSnapshot(
                waterTemperature: water, waveHeight: wave, windSpeed: wind,
                airTemperature: 28.0, precipitation: 0,
                currentDirection: Double((Int(lat * 10) * 17) % 360), currentSpeed: 0.38
                    + Double(id.utf8.reduce(0) { $0 + Int($1) } % 23) / 100
            ), activities: activities,
            mockFields: Set(BeachDataField.allCases),
            fieldProvenance: Dictionary(uniqueKeysWithValues: BeachDataField.allCases.map { ($0, .mock()) })
        )
    }

    static let beaches: [Beach] = [
        beach("yeongildae", "영일대해수욕장", "포항시", 36.0571, 129.3787, risk: .good, recent: false, water: 24.2, wave: 0.6, wind: 3.2, summary: "도심 접근성이 좋고 야간 산책과 물놀이를 함께 즐기기 좋아요."),
        beach("songdo", "송도해수욕장", "포항시", 36.0328, 129.3785, risk: .good, recent: false, water: 24.0, wave: 0.5, wind: 3.1, summary: "포항 도심과 가까운 잔잔한 해변이에요."),
        beach("chilpo", "칠포해수욕장", "포항시", 36.1365, 129.3962, risk: .caution, recent: true, water: 23.8, wave: 1.1, wind: 4.4, summary: "넓은 백사장과 적당한 파도로 가족 여행에 인기예요."),
        beach("wolpo", "월포해수욕장", "포항시", 36.2034, 129.3715, risk: .good, recent: false, water: 23.6, wave: 1.2, wind: 4.0, summary: "서핑 입문자와 캠핑 여행자가 즐겨 찾는 해변이에요."),
        beach("hwajin", "화진해수욕장", "포항시", 36.2858, 129.3736, risk: .good, recent: false, water: 23.4, wave: 0.8, wind: 3.8, summary: "소나무 숲과 맑은 바다가 어우러진 조용한 해변이에요."),
        beach("jangsa", "장사해수욕장", "영덕군", 36.2819, 129.3768, risk: .caution, recent: true, water: 23.5, wave: 0.9, wind: 4.1, summary: "긴 백사장과 완만한 수심으로 잘 알려진 해변이에요."),
        beach("namho", "남호해수욕장", "영덕군", 36.3278, 129.3808, risk: .good, recent: false, water: 23.3, wave: 0.7, wind: 3.6, summary: "한적한 분위기와 깨끗한 모래가 매력적인 해변이에요."),
        beach("samseong", "삼사해상공원 해변", "영덕군", 36.3594, 129.3891, risk: .good, recent: false, water: 23.2, wave: 0.8, wind: 3.7, summary: "해상공원 전망과 바다 산책을 함께 즐길 수 있어요."),
        beach("deokcheon", "덕천해수욕장", "영덕군", 36.4120, 129.4271, risk: .good, recent: false, water: 23.1, wave: 0.6, wind: 3.0, summary: "붐비지 않아 여유롭게 쉬기 좋은 작은 해변이에요."),
        beach("goraebul", "고래불해수욕장", "영덕군", 36.5972, 129.4113, risk: .caution, recent: true, water: 22.9, wave: 1.3, wind: 5.1, summary: "긴 해안선과 송림이 유명한 영덕 대표 해수욕장이에요."),
        beach("daejeon", "대진해수욕장", "영덕군", 36.5612, 129.4184, risk: .good, recent: false, water: 23.0, wave: 0.9, wind: 4.2, summary: "맑은 물과 고운 모래로 가족 물놀이에 좋아요."),
        beach("ojeon", "오전해수욕장", "영덕군", 36.6439, 129.4187, risk: .good, recent: false, water: 22.8, wave: 0.7, wind: 3.8, summary: "소박한 어촌 풍경과 잔잔한 바다를 만날 수 있어요."),
        beach("hujeong", "후정해수욕장", "울진군", 37.0742, 129.4104, risk: .caution, recent: true, water: 22.5, wave: 1.0, wind: 4.9, summary: "깨끗한 수질과 넓은 해변으로 유명해요."),
        beach("mangyang", "망양정해수욕장", "울진군", 36.9744, 129.4174, risk: .good, recent: false, water: 22.7, wave: 0.8, wind: 3.6, summary: "망양정과 왕피천을 함께 둘러보기 좋은 해변이에요."),
        beach("giseong", "기성망양해수욕장", "울진군", 36.7989, 129.4665, risk: .good, recent: false, water: 22.9, wave: 0.7, wind: 3.4, summary: "탁 트인 수평선과 한적한 캠핑 분위기가 좋아요."),
        beach("gusan", "구산해수욕장", "울진군", 36.7589, 129.4684, risk: .good, recent: false, water: 23.0, wave: 0.6, wind: 3.3, summary: "수심이 완만하고 송림이 있어 가족 여행에 잘 맞아요."),
        beach("najeong", "나정고운모래해변", "경주시", 35.7879, 129.4938, risk: .good, recent: false, water: 24.6, wave: 0.8, wind: 3.9, summary: "고운 모래와 해안 산책로가 아름다운 경주 대표 해변이에요."),
        beach("jeonchon", "전촌솔밭해변", "경주시", 35.7791, 129.4928, risk: .good, recent: false, water: 24.5, wave: 0.6, wind: 3.5, summary: "솔숲 그늘과 잔잔한 만이 어우러진 휴식형 해변이에요."),
        beach("bonggil", "봉길대왕암해변", "경주시", 35.7385, 129.4840, risk: .caution, recent: true, water: 24.4, wave: 1.4, wind: 5.5, summary: "문무대왕릉을 바라보는 특별한 경관의 해변이에요."),
        beach("gwanseong", "관성솔밭해변", "경주시", 35.6587, 129.4567, risk: .good, recent: false, water: 24.7, wave: 0.7, wind: 3.4, summary: "넓은 솔밭과 캠핑 환경이 좋은 남경주 해변이에요."),
        beach("ojang", "오류고아라해변", "경주시", 35.8278, 129.5068, risk: .good, recent: false, water: 24.3, wave: 0.9, wind: 4.0, summary: "감포의 푸른 바다와 캠핑장을 함께 이용하기 좋아요."),
        beach("cheoksa", "척사해수욕장", "울진군", 36.9208, 129.4215, risk: .good, recent: false, water: 22.8, wave: 0.7, wind: 3.2, summary: "작고 조용해 현지인이 즐겨 찾는 해변이에요."),
        beach("sandeul", "산포해수욕장", "울진군", 36.8894, 129.4322, risk: .caution, recent: true, water: 22.8, wave: 1.1, wind: 4.5, summary: "해안도로 여행 중 쉬어가기 좋은 탁 트인 해변이에요."),
        beach("dodong", "도구해수욕장", "포항시", 35.9900, 129.4443, risk: .good, recent: false, water: 24.3, wave: 0.8, wind: 3.8, summary: "포항 남부의 넓은 바다와 산책로가 매력적인 해변이에요.")
    ]

    static let tracks: [JellyfishTrack] = [
        JellyfishTrack(id: "track-north", species: "Nomura's jellyfish", observedAt: "Observed today at 08:00", checkpoints: [
            (-24, .init(latitude: 36.310, longitude: 129.472)),
            (-21, .init(latitude: 36.301, longitude: 129.468)),
            (-18, .init(latitude: 36.291, longitude: 129.463)),
            (-15, .init(latitude: 36.282, longitude: 129.458)),
            (-12, .init(latitude: 36.272, longitude: 129.454)),
            (-9, .init(latitude: 36.263, longitude: 129.449)),
            (-6, .init(latitude: 36.254, longitude: 129.444)),
            (-3, .init(latitude: 36.244, longitude: 129.439)),
            (0, .init(latitude: 36.235, longitude: 129.435)),
            (3, .init(latitude: 36.220, longitude: 129.428)),
            (6, .init(latitude: 36.205, longitude: 129.421)),
            (9, .init(latitude: 36.185, longitude: 129.414)),
            (12, .init(latitude: 36.165, longitude: 129.408)),
        ]),
        JellyfishTrack(id: "track-south", species: "Moon jellyfish", observedAt: "Observed yesterday at 19:00", checkpoints: [
            (-24, .init(latitude: 35.942, longitude: 129.592)),
            (-21, .init(latitude: 35.931, longitude: 129.586)),
            (-18, .init(latitude: 35.920, longitude: 129.580)),
            (-15, .init(latitude: 35.910, longitude: 129.574)),
            (-12, .init(latitude: 35.899, longitude: 129.568)),
            (-9, .init(latitude: 35.888, longitude: 129.562)),
            (-6, .init(latitude: 35.877, longitude: 129.556)),
            (-3, .init(latitude: 35.866, longitude: 129.550)),
            (0, .init(latitude: 35.855, longitude: 129.545)),
            (3, .init(latitude: 35.840, longitude: 129.535)),
            (6, .init(latitude: 35.824, longitude: 129.526)),
            (9, .init(latitude: 35.808, longitude: 129.517)),
            (12, .init(latitude: 35.791, longitude: 129.508)),
        ])
    ]

    static var modeledTracks: [JellyfishTrack] {
        let engine = JellyfishPredictionEngine()
        return tracks.enumerated().map { index, track in
            let origin = track.coordinate(at: 0)
            let referenceBeach = beaches.min {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
                < CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                    .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
            } ?? beaches[0]
            let marine = referenceBeach.marine
            let prediction = engine.predict(
                observation: JellyfishObservation(coordinate: origin, species: track.species),
                forcing: OceanForcing(
                    currentDirection: marine.currentDirection,
                    currentSpeed: marine.currentSpeed,
                    windDirection: marine.currentDirection + 35,
                    windSpeed: marine.windSpeed,
                    waveHeight: marine.waveHeight,
                    waterTemperature: marine.waterTemperature
                ),
                seed: UInt64(20_260_822 + index * 10_007)
            )
            let history = track.checkpoints.filter { $0.hour <= 0 }
            let future = prediction.points.filter { $0.hour > 0 }.map { ($0.hour, $0.coordinate) }
            return JellyfishTrack(
                id: track.id,
                species: track.species,
                observedAt: track.observedAt,
                checkpoints: history + future,
                uncertaintyRadii: Dictionary(
                    uniqueKeysWithValues: prediction.points.map { ($0.hour, $0.uncertaintyRadius) }
                ),
                particleSnapshots: Dictionary(
                    uniqueKeysWithValues: prediction.points.map { ($0.hour, $0.particles) }
                )
            )
        }
    }
}
