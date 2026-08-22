import Foundation
import CoreLocation

enum RiskLevel: Int, CaseIterable, Comparable, Codable {
    case good = 0
    case caution = 1
    case later = 2
    case unknown = 3

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .good: "Safe"
        case .caution: "Caution"
        case .later: "High Risk"
        case .unknown: "Check Status"
        }
    }

    var shortTitle: String {
        switch self {
        case .good: "Safe"
        case .caution: "Caution"
        case .later: "High Risk"
        case .unknown: "Check"
        }
    }
}

enum ActivityGroup: String, CaseIterable, Identifiable, Codable {
    case calmWater = "Swimming · Snorkeling"
    case board = "Surfing · Paddleboard"
    case offshore = "Fishing · Boating"
    var id: String { rawValue }
}

struct MarineSnapshot: Hashable, Codable {
    let waterTemperature: Double
    let waveHeight: Double
    let windSpeed: Double
    let airTemperature: Double
    let precipitation: Double
    let currentDirection: Double
    let currentSpeed: Double
}

enum BeachDataField: String, Hashable, Codable, CaseIterable {
    case location, address, facilities
    case jellyfishSightings, species, toxicity
    case baseRisk, activities
    case waterTemperature, waveHeight, wind, airTemperature, precipitation, current
}

enum DataQuality: String, Hashable, Codable {
    case officialExact
    case officialRegional
    case derived
    case stale
    case mock
    case missing

    var badge: String? {
        switch self {
        case .officialExact: nil
        case .officialRegional: "REGIONAL DATA"
        case .derived: "PREDICTION"
        case .stale: "RECENT DATA"
        case .mock: nil
        case .missing: "CHECK LATER"
        }
    }
}

struct DataProvenance: Hashable, Codable {
    let source: String
    let observedAt: Date?
    let fetchedAt: Date
    let quality: DataQuality
    let spatialUncertaintyMeters: Double?

    static func mock(source: String = "Demo sample", fetchedAt: Date = Date()) -> Self {
        .init(source: source, observedAt: nil, fetchedAt: fetchedAt, quality: .mock, spatialUncertaintyMeters: nil)
    }

    static func live(
        source: String,
        observedAt: Date? = nil,
        fetchedAt: Date = Date(),
        quality: DataQuality = .officialExact,
        spatialUncertaintyMeters: Double? = nil
    ) -> Self {
        .init(
            source: source,
            observedAt: observedAt,
            fetchedAt: fetchedAt,
            quality: quality,
            spatialUncertaintyMeters: spatialUncertaintyMeters
        )
    }

    var timestamp: Date { observedAt ?? fetchedAt }
}

struct Beach: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let city: String
    let latitude: Double
    let longitude: Double
    let summary: String
    let address: String
    let facilities: [String]
    let recentJellyfish: Bool
    let lastObservation: String
    let species: String
    let toxicity: String
    let baseRisk: RiskLevel
    let marine: MarineSnapshot
    let activities: [ActivityGroup: RiskLevel]
    var mockFields: Set<BeachDataField> = []
    var fieldProvenance: [BeachDataField: DataProvenance] = [:]

    func provenance(for field: BeachDataField) -> DataProvenance {
        if let value = fieldProvenance[field] { return value }
        return mockFields.contains(field)
            ? .mock()
            : .live(source: "Unknown source", quality: .missing)
    }

    func quality(for fields: BeachDataField...) -> DataQuality {
        quality(for: fields)
    }

    private func quality(for fields: [BeachDataField]) -> DataQuality {
        let qualities = fields.map { provenance(for: $0).quality }
        if qualities.contains(.mock) { return .mock }
        if qualities.contains(.missing) { return .missing }
        if qualities.contains(.stale) { return .stale }
        if qualities.contains(.officialRegional) { return .officialRegional }
        if qualities.contains(.derived) { return .derived }
        return .officialExact
    }

    func usesMock(_ fields: BeachDataField...) -> Bool {
        fields.contains { provenance(for: $0).quality == .mock }
    }

    func marked(_ value: String, fields: BeachDataField...) -> String {
        value
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        Self.englishNames[id] ?? name
    }

    var displayCity: String {
        switch city {
        case "포항시": "Pohang"
        case "영덕군": "Yeongdeok"
        case "울진군": "Uljin"
        case "경주시": "Gyeongju"
        default: city
        }
    }

    var recommendedVisitTime: String {
        switch baseRisk {
        case .good: "Today · before 6 PM"
        case .caution: "Check again in 3h"
        case .later: "Try another time"
        case .unknown: "Confirm on-site"
        }
    }

    var recentSightingsCount: Int {
        recentJellyfish ? (id.utf8.reduce(0) { $0 + Int($1) } % 4) + 1 : 0
    }

    var currentDescription: String {
        if marine.currentSpeed >= 0.65 { return "Strong Onshore Current" }
        if marine.currentSpeed >= 0.4 { return "Check Direction" }
        return "Relatively Calm"
    }

    var surfStatus: String {
        guard baseRisk != .later else { return "Not Recommended" }
        return marine.waveHeight >= 0.7 && marine.waveHeight <= 1.8 ? "Good" : "Check First"
    }

    var sightingSummary: String {
        recentJellyfish ? lastObservation : "No sightings reported in the latest bulletin"
    }

    var displaySpecies: String {
        recentJellyfish ? species : "None reported"
    }

    var displayFacilities: [String] {
        facilities.map {
            switch $0 {
            case "주차": "Parking"
            case "샤워장": "Showers"
            case "화장실": "Restrooms"
            default: $0
            }
        }
    }

    private static let englishNames: [String: String] = [
        "yeongildae": "Yeongildae Beach", "songdo": "Songdo Beach", "chilpo": "Chilpo Beach",
        "wolpo": "Wolpo Beach", "hwajin": "Hwajin Beach", "jangsa": "Jangsa Beach",
        "namho": "Namho Beach", "samseong": "Samsa Coast", "deokcheon": "Deokcheon Beach",
        "goraebul": "Goraebul Beach", "daejeon": "Daejin Beach", "ojeon": "Ojeon Beach",
        "hujeong": "Hujeong Beach", "mangyang": "Mangyangjeong Beach", "giseong": "Giseong Mangyang Beach",
        "gusan": "Gusan Beach", "najeong": "Najeong Beach", "jeonchon": "Jeonchon Pine Beach",
        "bonggil": "Bonggil Beach", "gwanseong": "Gwanseong Beach", "ojang": "Oryu Goara Beach",
        "cheoksa": "Cheoksa Beach", "sandeul": "Sanpo Beach", "dodong": "Dogu Beach"
    ]
}

struct JellyfishTrack: Identifiable, Hashable {
    static let minimumSupportedParticleCoverage = 0.75

    enum OriginKind: String, Hashable {
        case mock
        case officialPoint
        case officialRegionEstimate

        var needsCautionMarker: Bool { self != .officialPoint }
    }

    let id: String
    let species: String
    let observedAt: String
    let originKind: OriginKind
    let checkpoints: [(hour: Double, coordinate: CLLocationCoordinate2D)]
    let uncertaintyRadii: [Double: Double]
    let particleSnapshots: [Double: [JellyfishParticleSnapshot]]
    let provenance: DataProvenance

    init(
        id: String,
        species: String,
        observedAt: String,
        originKind: OriginKind = .mock,
        checkpoints: [(hour: Double, coordinate: CLLocationCoordinate2D)],
        uncertaintyRadii: [Double: Double] = [:],
        particleSnapshots: [Double: [JellyfishParticleSnapshot]] = [:],
        provenance: DataProvenance? = nil
    ) {
        self.id = id
        self.species = species
        self.observedAt = observedAt
        self.originKind = originKind
        self.checkpoints = checkpoints
        self.uncertaintyRadii = uncertaintyRadii
        self.particleSnapshots = particleSnapshots
        self.provenance = provenance ?? (originKind == .mock
            ? .mock(source: "Demo route")
            : .live(
                source: "NIFS",
                quality: originKind == .officialRegionEstimate ? .officialRegional : .officialExact
            ))
    }

    static func == (lhs: JellyfishTrack, rhs: JellyfishTrack) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var supportedFutureHorizon: Double {
        guard !particleSnapshots.isEmpty else {
            return max(checkpoints.filter { $0.hour >= 0 }.map(\.hour).max() ?? 0, 0)
        }
        let referenceIDs = referenceParticleIDs
        guard !referenceIDs.isEmpty else { return 0 }
        return max(
            particleSnapshots.filter { hour, particles in
                hour >= 0
                    && activeCoverage(in: particles, relativeTo: referenceIDs)
                        >= Self.minimumSupportedParticleCoverage
            }.map(\.key).max() ?? 0,
            0
        )
    }

    func activeParticleCoverage(at hour: Double) -> Double? {
        guard hour >= 0 else { return nil }
        let referenceIDs = referenceParticleIDs
        guard !referenceIDs.isEmpty else { return nil }
        let frame = rawParticles(at: hour)
        guard !frame.isEmpty else { return nil }
        return activeCoverage(in: frame, relativeTo: referenceIDs)
    }

    func coordinate(at hour: Double) -> CLLocationCoordinate2D {
        // Particle forecasts begin at the observation time. Historical slider values
        // must use the observed checkpoint trail instead of clamping to the first
        // forecast particle snapshot at hour zero.
        if hour >= 0, !particleSnapshots.isEmpty {
            let waterParticles = particles(at: hour).filter {
                GyeongbukCoastline.mask.isWater($0.coordinate)
            }
            if !waterParticles.isEmpty {
                let meanLatitude = waterParticles.map(\.coordinate.latitude).reduce(0, +) / Double(waterParticles.count)
                let meanLongitude = waterParticles.map(\.coordinate.longitude).reduce(0, +) / Double(waterParticles.count)
                return waterParticles.min {
                    hypot($0.coordinate.latitude - meanLatitude, $0.coordinate.longitude - meanLongitude)
                        < hypot($1.coordinate.latitude - meanLatitude, $1.coordinate.longitude - meanLongitude)
                }?.coordinate ?? waterParticles[0].coordinate
            }
        }
        if hour < 0, !checkpoints.contains(where: { $0.hour < 0 }),
           let current = checkpoints.first(where: { $0.hour == 0 }),
           let next = checkpoints.filter({ $0.hour > 0 }).min(by: { $0.hour < $1.hour }) {
            let fraction = hour / next.hour
            let extrapolated = CLLocationCoordinate2D(
                latitude: current.coordinate.latitude
                    + (next.coordinate.latitude - current.coordinate.latitude) * fraction,
                longitude: current.coordinate.longitude
                    + (next.coordinate.longitude - current.coordinate.longitude) * fraction
            )
            return Self.lastWaterCoordinate(from: current.coordinate, toward: extrapolated)
        }
        if let exact = checkpoints.first(where: { $0.hour == hour }) { return exact.coordinate }
        let sorted = checkpoints.sorted { $0.hour < $1.hour }
        guard let first = sorted.first, let last = sorted.last else {
            return CLLocationCoordinate2D(latitude: 36.0571, longitude: 129.3787)
        }
        let lower = sorted.last(where: { $0.hour <= hour }) ?? first
        let upper = sorted.first(where: { $0.hour >= hour }) ?? last
        guard lower.hour != upper.hour else { return lower.coordinate }
        let fraction = min(max((hour - lower.hour) / (upper.hour - lower.hour), 0), 1)
        return .init(
            latitude: lower.coordinate.latitude + (upper.coordinate.latitude - lower.coordinate.latitude) * fraction,
            longitude: lower.coordinate.longitude + (upper.coordinate.longitude - lower.coordinate.longitude) * fraction
        )
    }

    func historyPath(at hour: Double) -> [CLLocationCoordinate2D] {
        let end = min(hour, 0)
        if checkpoints.contains(where: { $0.hour < 0 }) {
            return checkpoints.filter { $0.hour <= end }.map(\.coordinate)
        }
        // Official regional reports do not contain an exact historical route.
        // Only explicitly labelled demo tracks may synthesize a preview backcast.
        guard originKind == .mock, end < 0 else { return [] }
        var path: [CLLocationCoordinate2D] = []
        var sampleHour = -24.0
        while sampleHour <= end + 0.000_1 {
            let candidate = coordinate(at: min(sampleHour, end))
            if let previous = path.last, !Self.segmentIsWater(from: previous, to: candidate) { break }
            path.append(candidate)
            if sampleHour == end { break }
            sampleHour = min(sampleHour + 0.5, end)
        }
        return path
    }

    func forecastPath(at hour: Double) -> [CLLocationCoordinate2D] {
        guard hour > 0, supportedFutureHorizon > 0,
              let current = checkpoints.first(where: { $0.hour == 0 })?.coordinate else { return [] }
        let supportedEnd = min(hour, supportedFutureHorizon)
        var path = [current]
        var sampleHour = min(0.5, supportedEnd)
        while sampleHour <= supportedEnd + 0.000_1 {
            let candidate = coordinate(at: min(sampleHour, supportedEnd))
            guard Self.segmentIsWater(from: path[path.count - 1], to: candidate) else { break }
            path.append(candidate)
            if sampleHour == supportedEnd { break }
            sampleHour = min(sampleHour + 0.5, supportedEnd)
        }
        return path
    }

    private static func segmentIsWater(
        from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D
    ) -> Bool {
        let distance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        let samples = max(Int(ceil(distance / 100)), 1)
        return (1...samples).allSatisfy { index in
            let fraction = Double(index) / Double(samples)
            return GyeongbukCoastline.mask.isWater(.init(
                latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                longitude: start.longitude + (end.longitude - start.longitude) * fraction
            ))
        }
    }

    private static func lastWaterCoordinate(
        from start: CLLocationCoordinate2D, toward end: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let distance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        let samples = max(Int(ceil(distance / 100)), 1)
        var lastWater = start
        for index in 1...samples {
            let fraction = Double(index) / Double(samples)
            let candidate = CLLocationCoordinate2D(
                latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                longitude: start.longitude + (end.longitude - start.longitude) * fraction
            )
            guard GyeongbukCoastline.mask.isWater(candidate) else { return lastWater }
            lastWater = candidate
        }
        return lastWater
    }

    func uncertaintyRadius(at hour: Double) -> Double {
        if hour < 0 {
            let historicalSpan = max(abs(hour), 1)
            return max(700, 1_050 + historicalSpan * 28)
        }
        if let exact = uncertaintyRadii[hour] { return exact }
        let hours = uncertaintyRadii.keys.sorted()
        guard let first = hours.first, let last = hours.last else { return 1_500 + max(hour, 0) * 220 }
        let lower = hours.last(where: { $0 <= hour }) ?? first
        let upper = hours.first(where: { $0 >= hour }) ?? last
        guard let lowerValue = uncertaintyRadii[lower], lower != upper, let upperValue = uncertaintyRadii[upper] else {
            return uncertaintyRadii[lower] ?? 1_500
        }
        let fraction = min(max((hour - lower) / (upper - lower), 0), 1)
        return lowerValue + (upperValue - lowerValue) * fraction
    }

    func particles(at hour: Double) -> [JellyfishParticleSnapshot] {
        guard hour < 0 || hour <= supportedFutureHorizon + 0.000_001 else { return [] }
        return rawParticles(at: hour)
    }

    private func rawParticles(at hour: Double) -> [JellyfishParticleSnapshot] {
        if let exact = particleSnapshots[hour] { return exact }
        let hours = particleSnapshots.keys.sorted()
        guard let first = hours.first, let last = hours.last else { return [] }
        guard hour >= first, hour <= last else { return [] }
        let lowerHour = hours.last(where: { $0 <= hour }) ?? first
        let upperHour = hours.first(where: { $0 >= hour }) ?? last
        guard let lower = particleSnapshots[lowerHour] else { return [] }
        guard lowerHour != upperHour, let upper = particleSnapshots[upperHour] else {
            return lower
        }
        let fraction = min(max((hour - lowerHour) / (upperHour - lowerHour), 0), 1)
        let upperByID = Dictionary(uniqueKeysWithValues: upper.enumerated().map { index, particle in
            (particle.id >= 0 ? particle.id : index, particle)
        })
        return lower.enumerated().map { index, start in
            let stableID = start.id >= 0 ? start.id : index
            guard !start.isBeached, let end = upperByID[stableID] else {
                return JellyfishParticleSnapshot(
                    id: stableID,
                    coordinate: start.coordinate,
                    isBeached: start.isBeached,
                    isInactive: start.isInactive
                )
            }
            return JellyfishParticleSnapshot(
                id: stableID,
                coordinate: .init(
                    latitude: start.coordinate.latitude + (end.coordinate.latitude - start.coordinate.latitude) * fraction,
                    longitude: start.coordinate.longitude + (end.coordinate.longitude - start.coordinate.longitude) * fraction
                ),
                isBeached: fraction >= 1 && end.isBeached,
                isInactive: start.isInactive || (fraction > 0 && end.isInactive)
            )
        }
    }

    func particleHistory(upTo hour: Double) -> [[JellyfishParticleSnapshot]] {
        guard hour >= 0, hour <= supportedFutureHorizon + 0.000_001 else { return [] }
        let completed = particleSnapshots.keys.filter { $0 <= hour }.sorted().compactMap { particleSnapshots[$0] }
        guard !particleSnapshots.keys.contains(hour) else { return completed }
        let interpolated = particles(at: hour)
        return interpolated.isEmpty ? completed : completed + [interpolated]
    }

    func entryFraction(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        upTo hour: Double
    ) -> Double? {
        guard hour >= 0, radius > 0 else { return nil }
        let frames = particleHistory(upTo: hour)
        let referenceIDs = referenceParticleIDs
        guard !frames.isEmpty, !referenceIDs.isEmpty,
              let coverage = activeParticleCoverage(at: hour),
              coverage >= Self.minimumSupportedParticleCoverage else { return nil }
        let selectedFrame = rawParticles(at: hour)
        let activeIDs = activeParticleIDs(in: selectedFrame, relativeTo: referenceIDs)
        guard !activeIDs.isEmpty else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var entered: Set<Int> = []
        for frame in frames {
            for (index, particle) in frame.enumerated() {
                let id = particle.id >= 0 ? particle.id : index
                guard activeIDs.contains(id), !entered.contains(id), !particle.isInactive else { continue }
                let point = particle.coordinate
                if target.distance(from: CLLocation(
                    latitude: point.latitude,
                    longitude: point.longitude
                )) <= radius { entered.insert(id) }
            }
        }
        return Double(entered.count) / Double(activeIDs.count)
    }

    private var referenceParticleIDs: Set<Int> {
        guard let referenceHour = particleSnapshots.keys.filter({ $0 >= 0 }).min(),
              let particles = particleSnapshots[referenceHour] else { return [] }
        return Set(particles.enumerated().map { index, particle in
            particle.id >= 0 ? particle.id : index
        })
    }

    private func activeParticleIDs(
        in particles: [JellyfishParticleSnapshot], relativeTo referenceIDs: Set<Int>
    ) -> Set<Int> {
        Set(particles.enumerated().compactMap { index, particle in
            let id = particle.id >= 0 ? particle.id : index
            return !particle.isInactive && referenceIDs.contains(id) ? id : nil
        })
    }

    private func activeCoverage(
        in particles: [JellyfishParticleSnapshot], relativeTo referenceIDs: Set<Int>
    ) -> Double {
        guard !referenceIDs.isEmpty else { return 0 }
        return Double(activeParticleIDs(in: particles, relativeTo: referenceIDs).count)
            / Double(referenceIDs.count)
    }
}

enum MapLayer: String, CaseIterable, Identifiable {
    case predictedPath = "Predicted Route"
    case current = "Current"
    case temperature = "Water Temperature"
    var id: String { rawValue }
}
