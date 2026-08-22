import Foundation
import CoreLocation

struct JellyfishObservation {
    let coordinate: CLLocationCoordinate2D
    let species: String
    let initialUncertaintyRadius: Double

    init(coordinate: CLLocationCoordinate2D, species: String, initialUncertaintyRadius: Double = 350) {
        self.coordinate = coordinate
        self.species = species
        self.initialUncertaintyRadius = initialUncertaintyRadius
    }
}

struct OceanForcing: Hashable {
    let currentDirection: Double
    let currentSpeed: Double
    let windDirection: Double
    let windSpeed: Double
    let waveHeight: Double
    let waterTemperature: Double
}

struct OceanFieldSample: Hashable {
    let coordinate: CLLocationCoordinate2D
    let hour: Double
    let forcing: OceanForcing

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.hour == rhs.hour && lhs.forcing == rhs.forcing
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(hour)
        hasher.combine(forcing)
    }
}

enum OceanFieldTemporalPolicy {
    case strict
    case boundedPersistence(validHours: ClosedRange<Double>)
}

/// Interpolates the ocean state at every particle coordinate and forecast time.
struct SpatiotemporalOceanField {
    let samples: [OceanFieldSample]
    let maximumSpatialExtrapolationMeters: Double
    private let isTemporallyConstant: Bool
    private let temporalPolicy: OceanFieldTemporalPolicy

    init(
        samples: [OceanFieldSample],
        maximumSpatialExtrapolationMeters: Double = 120_000,
        temporalPolicy: OceanFieldTemporalPolicy = .strict
    ) {
        self.samples = samples
        self.maximumSpatialExtrapolationMeters = maximumSpatialExtrapolationMeters
        isTemporallyConstant = false
        self.temporalPolicy = temporalPolicy
    }

    init(constant forcing: OceanForcing, around coordinate: CLLocationCoordinate2D) {
        samples = [.init(coordinate: coordinate, hour: 0, forcing: forcing)]
        maximumSpatialExtrapolationMeters = .greatestFiniteMagnitude
        isTemporallyConstant = true
        temporalPolicy = .strict
    }

    func forcing(at coordinate: CLLocationCoordinate2D, hour: Double) -> OceanForcing? {
        guard !samples.isEmpty else { return nil }
        let hours = Array(Set(samples.map(\.hour))).sorted()
        guard let first = hours.first, let last = hours.last else { return nil }
        if isTemporallyConstant {
            return spatialForcing(at: coordinate, hour: first)
        }
        switch temporalPolicy {
        case .strict:
            guard hour >= first, hour <= last else { return nil }
        case let .boundedPersistence(validHours):
            guard validHours.contains(hour) else { return nil }
            if hour <= first { return spatialForcing(at: coordinate, hour: first) }
            if hour >= last { return spatialForcing(at: coordinate, hour: last) }
        }

        guard let lowerHour = hours.last(where: { $0 <= hour }),
              let upperHour = hours.first(where: { $0 >= hour }) else { return nil }
        guard let lower = spatialForcing(at: coordinate, hour: lowerHour) else { return nil }
        guard lowerHour != upperHour else { return lower }
        guard let upper = spatialForcing(at: coordinate, hour: upperHour) else { return nil }
        let fraction = (hour - lowerHour) / (upperHour - lowerHour)
        return Self.weighted([lower, upper], weights: [1 - fraction, fraction])
    }

    private func spatialForcing(at coordinate: CLLocationCoordinate2D, hour: Double) -> OceanForcing? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let candidates = samples.filter { $0.hour == hour }.map {
            ($0, location.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)))
        }.sorted { $0.1 < $1.1 }
        guard let nearest = candidates.first, nearest.1 <= maximumSpatialExtrapolationMeters else { return nil }
        if nearest.1 < 1 { return nearest.0.forcing }
        let selected = Array(candidates.prefix(4))
        let rawWeights = selected.map { 1 / max($0.1 * $0.1, 1) }
        let total = rawWeights.reduce(0, +)
        return Self.weighted(selected.map(\.0.forcing), weights: rawWeights.map { $0 / total })
    }

    private static func weighted(_ values: [OceanForcing], weights: [Double]) -> OceanForcing {
        func scalar(_ keyPath: KeyPath<OceanForcing, Double>) -> Double {
            zip(values, weights).reduce(0) { $0 + $1.0[keyPath: keyPath] * $1.1 }
        }
        func vector(
            direction directionKeyPath: KeyPath<OceanForcing, Double>,
            speed speedKeyPath: KeyPath<OceanForcing, Double>
        ) -> (direction: Double, speed: Double) {
            let vector = zip(values, weights).reduce(into: (east: 0.0, north: 0.0)) { result, item in
                let radians = item.0[keyPath: directionKeyPath] * .pi / 180
                let weightedSpeed = item.0[keyPath: speedKeyPath] * item.1
                result.east += sin(radians) * weightedSpeed
                result.north += cos(radians) * weightedSpeed
            }
            let speed = hypot(vector.east, vector.north)
            guard speed > 1e-12 else { return (direction: 0, speed: 0) }
            let degrees = atan2(vector.east, vector.north) * 180 / .pi
            return (direction: degrees >= 0 ? degrees : degrees + 360, speed: speed)
        }
        let current = vector(direction: \.currentDirection, speed: \.currentSpeed)
        let wind = vector(direction: \.windDirection, speed: \.windSpeed)
        return OceanForcing(
            currentDirection: current.direction, currentSpeed: current.speed,
            windDirection: wind.direction, windSpeed: wind.speed,
            waveHeight: scalar(\.waveHeight), waterTemperature: scalar(\.waterTemperature)
        )
    }
}

protocol CoastlineMask {
    func isWater(_ coordinate: CLLocationCoordinate2D) -> Bool
}

struct AllWaterMask: CoastlineMask {
    func isWater(_ coordinate: CLLocationCoordinate2D) -> Bool { true }
}

struct PolygonCoastlineMask: CoastlineMask {
    private struct Edge {
        let a: CLLocationCoordinate2D
        let b: CLLocationCoordinate2D
    }

    let landPolygons: [[CLLocationCoordinate2D]]
    private let minimumLatitude: Double
    private let latitudeBandHeight: Double
    private let edgesByLatitudeBand: [[Edge]]

    init(landPolygons: [[CLLocationCoordinate2D]], latitudeBandHeight: Double = 0.005) {
        self.landPolygons = landPolygons
        self.latitudeBandHeight = latitudeBandHeight
        let allLatitudes = landPolygons.flatMap { $0.map(\.latitude) }
        minimumLatitude = allLatitudes.min() ?? -90
        let maximumLatitude = allLatitudes.max() ?? 90
        let bandCount = max(Int(ceil((maximumLatitude - minimumLatitude) / latitudeBandHeight)) + 1, 1)
        var bands = Array(repeating: [Edge](), count: bandCount)

        for polygon in landPolygons where polygon.count >= 3 {
            for index in polygon.indices {
                let edge = Edge(a: polygon[index], b: polygon[index == 0 ? polygon.count - 1 : index - 1])
                let lower = max(Int(floor((min(edge.a.latitude, edge.b.latitude) - minimumLatitude) / latitudeBandHeight)), 0)
                let upper = min(Int(floor((max(edge.a.latitude, edge.b.latitude) - minimumLatitude) / latitudeBandHeight)), bandCount - 1)
                guard lower <= upper else { continue }
                for band in lower...upper { bands[band].append(edge) }
            }
        }
        edgesByLatitudeBand = bands
    }

    func isWater(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let band = Int(floor((coordinate.latitude - minimumLatitude) / latitudeBandHeight))
        guard edgesByLatitudeBand.indices.contains(band) else { return true }
        var inside = false
        for edge in edgesByLatitudeBand[band] {
            let a = edge.a, b = edge.b
            if (a.latitude > coordinate.latitude) != (b.latitude > coordinate.latitude) {
                let longitude = (b.longitude - a.longitude) * (coordinate.latitude - a.latitude)
                    / (b.latitude - a.latitude) + a.longitude
                if coordinate.longitude < longitude { inside.toggle() }
            }
        }
        return !inside
    }
}

private enum CoastlineGeoJSONLoader {
    private struct FeatureCollection: Decodable { let features: [Feature] }
    private struct Feature: Decodable { let geometry: Geometry }
    private struct Geometry: Decodable {
        let type: String
        let coordinates: [[[Double]]]
    }

    static func load(resource: String, bundle: Bundle = .main) -> [[CLLocationCoordinate2D]]? {
        guard let url = bundle.url(forResource: resource, withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(FeatureCollection.self, from: data)
        else { return nil }
        let polygons = collection.features.compactMap { feature -> [CLLocationCoordinate2D]? in
            guard feature.geometry.type == "Polygon", let exterior = feature.geometry.coordinates.first else { return nil }
            let coordinates = exterior.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count >= 2 else { return nil }
                return .init(latitude: pair[1], longitude: pair[0])
            }
            return coordinates.count >= 3 ? coordinates : nil
        }
        return polygons.isEmpty ? nil : polygons
    }
}

enum GyeongbukCoastline {
    private static let officialPolygons = CoastlineGeoJSONLoader.load(resource: "khoa_gyeongbuk_coastline")
    static let usesOfficialData = officialPolygons != nil
    static let source = usesOfficialData
        ? "MOF KHOA national coastline 2025-12-31"
        : "Bundled emergency fallback coastline"
    static let mask = PolygonCoastlineMask(landPolygons: officialPolygons ?? fallbackPolygons)

    private static let fallbackPolygons: [[CLLocationCoordinate2D]] = [[
        .init(latitude: 35.55, longitude: 128.60), .init(latitude: 37.25, longitude: 128.60),
        .init(latitude: 37.25, longitude: 129.37), .init(latitude: 37.08, longitude: 129.40),
        .init(latitude: 36.98, longitude: 129.42), .init(latitude: 36.88, longitude: 129.43),
        .init(latitude: 36.80, longitude: 129.46), .init(latitude: 36.65, longitude: 129.42),
        .init(latitude: 36.50, longitude: 129.40), .init(latitude: 36.36, longitude: 129.38),
        .init(latitude: 36.28, longitude: 129.37), .init(latitude: 36.20, longitude: 129.37),
        .init(latitude: 36.12, longitude: 129.39), .init(latitude: 36.05, longitude: 129.38),
        .init(latitude: 35.99, longitude: 129.44), .init(latitude: 35.90, longitude: 129.50),
        .init(latitude: 35.82, longitude: 129.50), .init(latitude: 35.74, longitude: 129.48),
        .init(latitude: 35.65, longitude: 129.46), .init(latitude: 35.55, longitude: 129.42)
    ]]
}

struct JellyfishParticleSnapshot: Hashable {
    let coordinate: CLLocationCoordinate2D
    let isBeached: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.isBeached == rhs.isBeached
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude); hasher.combine(coordinate.longitude); hasher.combine(isBeached)
    }
}

struct JellyfishPredictionPoint {
    let hour: Double
    let coordinate: CLLocationCoordinate2D
    let uncertaintyRadius: Double
    let particles: [JellyfishParticleSnapshot]

    var beachedFraction: Double {
        particles.isEmpty ? 0 : Double(particles.filter(\.isBeached).count) / Double(particles.count)
    }
}

struct JellyfishPredictionResult { let points: [JellyfishPredictionPoint] }

struct JellyfishPredictionEngine {
    var particleCount = 360
    var stepSeconds = 30.0 * 60.0
    var forecastHours = 24.0
    var checkpointHours = 3.0

    func predict(observation: JellyfishObservation, forcing: OceanForcing, seed: UInt64) -> JellyfishPredictionResult {
        predict(
            observation: observation,
            field: .init(constant: forcing, around: observation.coordinate),
            coastline: AllWaterMask(), seed: seed
        )
    }

    func predict(
        observation: JellyfishObservation,
        field: SpatiotemporalOceanField,
        coastline: any CoastlineMask,
        seed: UInt64
    ) -> JellyfishPredictionResult {
        let count = max(particleCount, 20)
        let steps = max(Int(forecastHours * 3600 / stepSeconds), 1)
        let checkpointStep = max(Int(checkpointHours * 3600 / stepSeconds), 1)
        let windage = speciesWindage(observation.species)
        let initialSigma = max(observation.initialUncertaintyRadius, 350) / 1.794
        var random = SeededRandomNumberGenerator(seed: seed)
        var particles = (0..<count).map { _ in
            initialParticle(observation, sigma: initialSigma, coastline: coastline, random: &random)
        }
        var points = [predictionPoint(hour: 0, particles: particles, origin: observation.coordinate)]

        for step in 1...steps {
            let hour = Double(step - 1) * stepSeconds / 3600
            for index in particles.indices where !particles[index].isBeached && !particles[index].isInactive {
                let currentCoordinate = Self.coordinate(
                    from: observation.coordinate, eastMeters: particles[index].east, northMeters: particles[index].north
                )
                guard let forcing = field.forcing(at: currentCoordinate, hour: hour) else {
                    particles[index].isInactive = true
                    continue
                }
                let current = velocity(
                    speed: forcing.currentSpeed * particles[index].speedBias,
                    direction: forcing.currentDirection + particles[index].directionBias
                )
                let wind = velocity(
                    speed: forcing.windSpeed * windage,
                    direction: forcing.windDirection + particles[index].directionBias * 0.35
                )
                let sigma = sqrt(2 * horizontalDiffusivity(forcing) * stepSeconds)
                let next = (
                    east: particles[index].east + (current.east + wind.east) * stepSeconds + random.gaussian() * sigma,
                    north: particles[index].north + (current.north + wind.north) * stepSeconds + random.gaussian() * sigma
                )
                if let boundary = firstCoastlineBoundary(
                    from: (particles[index].east, particles[index].north),
                    to: next,
                    origin: observation.coordinate,
                    coastline: coastline
                ) {
                    particles[index].east = boundary.east; particles[index].north = boundary.north
                    particles[index].isBeached = true
                } else {
                    particles[index].east = next.east; particles[index].north = next.north
                }
            }
            if step.isMultiple(of: checkpointStep) || step == steps {
                points.append(predictionPoint(
                    hour: Double(step) * stepSeconds / 3600,
                    particles: particles, origin: observation.coordinate
                ))
            }
        }
        return .init(points: points)
    }

    private func initialParticle(
        _ observation: JellyfishObservation,
        sigma: Double,
        coastline: any CoastlineMask,
        random: inout SeededRandomNumberGenerator
    ) -> Particle {
        for _ in 0..<24 {
            let east = random.gaussian() * sigma, north = random.gaussian() * sigma
            let coordinate = Self.coordinate(from: observation.coordinate, eastMeters: east, northMeters: north)
            if coastline.isWater(coordinate) {
                return .init(
                    east: east, north: north,
                    speedBias: max(0.55, 1 + random.gaussian() * 0.12),
                    directionBias: random.gaussian() * 6
                )
            }
        }
        return .init(
            east: 0,
            north: 0,
            speedBias: 1,
            directionBias: 0,
            isBeached: !coastline.isWater(observation.coordinate)
        )
    }

    private func lastWaterPosition(
        from start: (east: Double, north: Double),
        to end: (east: Double, north: Double),
        origin: CLLocationCoordinate2D,
        coastline: any CoastlineMask
    ) -> (east: Double, north: Double) {
        var water = start, land = end
        for _ in 0..<14 {
            let midpoint = (east: (water.east + land.east) / 2, north: (water.north + land.north) / 2)
            if coastline.isWater(Self.coordinate(from: origin, eastMeters: midpoint.east, northMeters: midpoint.north)) {
                water = midpoint
            } else { land = midpoint }
        }
        return water
    }

    /// Checks the full movement segment, not only its destination. Without this,
    /// a particle can jump across a narrow peninsula or island in one integration step.
    private func firstCoastlineBoundary(
        from start: (east: Double, north: Double),
        to end: (east: Double, north: Double),
        origin: CLLocationCoordinate2D,
        coastline: any CoastlineMask
    ) -> (east: Double, north: Double)? {
        let distance = hypot(end.east - start.east, end.north - start.north)
        let sampleCount = max(Int(ceil(distance / 100)), 1)
        var previous = start
        for sample in 1...sampleCount {
            let fraction = Double(sample) / Double(sampleCount)
            let candidate = (
                east: start.east + (end.east - start.east) * fraction,
                north: start.north + (end.north - start.north) * fraction
            )
            let coordinate = Self.coordinate(
                from: origin, eastMeters: candidate.east, northMeters: candidate.north
            )
            if !coastline.isWater(coordinate) {
                return lastWaterPosition(
                    from: previous, to: candidate, origin: origin, coastline: coastline
                )
            }
            previous = candidate
        }
        return nil
    }

    private func speciesWindage(_ species: String) -> Double {
        let value = species.lowercased()
        if value.contains("moon") || value.contains("보름달") { return 0.030 }
        if value.contains("nomura") || value.contains("노무라") { return 0.018 }
        return 0.022
    }

    private func horizontalDiffusivity(_ forcing: OceanForcing) -> Double {
        min(max(2.5 + max(forcing.waveHeight, 0) * 1.8 + max(forcing.waterTemperature - 20, 0) * 0.08, 2.5), 8)
    }

    private func velocity(speed: Double, direction: Double) -> (east: Double, north: Double) {
        let radians = direction * .pi / 180
        return (speed * sin(radians), speed * cos(radians))
    }

    private func predictionPoint(
        hour: Double, particles: [Particle], origin: CLLocationCoordinate2D
    ) -> JellyfishPredictionPoint {
        let moving = particles.filter { !$0.isInactive && !$0.isBeached }
        let available = particles.filter { !$0.isInactive }
        let included = moving.isEmpty ? (available.isEmpty ? particles : available) : moving
        let meanEast = included.map(\.east).reduce(0, +) / Double(included.count)
        let meanNorth = included.map(\.north).reduce(0, +) / Double(included.count)
        // An arithmetic centroid can lie on land when particles surround a bay or peninsula.
        // Use the real particle nearest the centroid as the visible tracker coordinate.
        let representative = included.min {
            hypot($0.east - meanEast, $0.north - meanNorth)
                < hypot($1.east - meanEast, $1.north - meanNorth)
        } ?? included[0]
        let distances = included.map { hypot($0.east - representative.east, $0.north - representative.north) }.sorted()
        let index = min(Int(Double(distances.count - 1) * 0.80), distances.count - 1)
        return .init(
            hour: hour,
            coordinate: Self.coordinate(
                from: origin, eastMeters: representative.east, northMeters: representative.north
            ),
            uncertaintyRadius: max(distances[index], 350),
            particles: particles.map {
                .init(
                    coordinate: Self.coordinate(from: origin, eastMeters: $0.east, northMeters: $0.north),
                    isBeached: $0.isBeached
                )
            }
        )
    }

    static func coordinate(
        from origin: CLLocationCoordinate2D, eastMeters: Double, northMeters: Double
    ) -> CLLocationCoordinate2D {
        let latitudeMeters = 111_320.0
        let longitudeMeters = latitudeMeters * cos(origin.latitude * .pi / 180)
        return .init(
            latitude: origin.latitude + northMeters / latitudeMeters,
            longitude: origin.longitude + eastMeters / max(longitudeMeters, 1)
        )
    }
}

private struct Particle {
    var east: Double
    var north: Double
    let speedBias: Double
    let directionBias: Double
    var isBeached = false
    var isInactive = false
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    private var spareGaussian: Double?

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func gaussian() -> Double {
        if let spareGaussian { self.spareGaussian = nil; return spareGaussian }
        let first = max(Double(next()) / Double(UInt64.max), 1e-12)
        let second = Double(next()) / Double(UInt64.max)
        let magnitude = sqrt(-2 * log(first)), angle = 2 * Double.pi * second
        spareGaussian = magnitude * sin(angle)
        return magnitude * cos(angle)
    }
}
