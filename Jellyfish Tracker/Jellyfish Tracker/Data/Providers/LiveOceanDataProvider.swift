import Foundation
import CoreLocation
import PDFKit

struct APIEnvironment {
    static let defaultCurrentEndpoint = "https://apis.data.go.kr/1192136/hfCurrent/GetHFCurrentApiService"
    static let defaultROMSEndpoint = "https://apis.data.go.kr/1192136/roms/GetRomsApiService"
    static let defaultTidalCurrentEndpoint = "https://khoa.go.kr/oceandata/api/tidalCurrentArea/search.do"
    let nifsKey: String?
    let tourismKey: String?
    let kmaHubKey: String?
    let currentServiceKey: String?
    let currentEndpoint: String?
    let romsServiceKey: String?
    let romsEndpoint: String?
    let tidalCurrentServiceKey: String?
    let tidalCurrentEndpoint: String?

    static var current: APIEnvironment {
        let environment = ProcessInfo.processInfo.environment
        return APIEnvironment(
            nifsKey: configuredValue(for: "NIFS_API_KEY", environment: environment),
            tourismKey: configuredValue(for: "TOUR_API_SERVICE_KEY", environment: environment)?.removingPercentEncoding,
            kmaHubKey: configuredValue(for: "KMA_API_HUB_KEY", environment: environment),
            currentServiceKey: configuredValue(for: "OCEAN_CURRENT_SERVICE_KEY", environment: environment)?.removingPercentEncoding,
            currentEndpoint: environment.nonEmptyValue(for: "OCEAN_CURRENT_ENDPOINT") ?? defaultCurrentEndpoint,
            romsServiceKey: (configuredValue(for: "ROMS_SERVICE_KEY", environment: environment)
                ?? configuredValue(for: "OCEAN_CURRENT_SERVICE_KEY", environment: environment))?.removingPercentEncoding,
            romsEndpoint: environment.nonEmptyValue(for: "ROMS_ENDPOINT") ?? defaultROMSEndpoint,
            tidalCurrentServiceKey: configuredValue(for: "TIDAL_CURRENT_SERVICE_KEY", environment: environment),
            tidalCurrentEndpoint: environment.nonEmptyValue(for: "TIDAL_CURRENT_ENDPOINT") ?? defaultTidalCurrentEndpoint
        )
    }

    private static func configuredValue(for key: String, environment: [String: String]) -> String? {
        let candidate = environment.nonEmptyValue(for: key)
            ?? bundledAPIKeys[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate,
              !candidate.isEmpty,
              !candidate.hasPrefix("YOUR_"),
              !candidate.contains("$(")
        else { return nil }
        return candidate
    }

    private static let bundledAPIKeys: [String: String] = {
        guard let url = Bundle.main.url(forResource: "APIKeys", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let keys = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return keys
    }()

    var hasLiveSource: Bool {
        nifsKey != nil || tourismKey != nil || kmaHubKey != nil
            || currentServiceKey != nil || romsServiceKey != nil || tidalCurrentServiceKey != nil
    }
}

enum OceanDataProviderFactory {
    static func make() -> OceanDataProviding {
        let configuration = APIEnvironment.current
        return configuration.hasLiveSource
            ? LiveOceanDataProvider(configuration: configuration)
            : MockOceanDataProvider()
    }
}

struct LiveOceanDataProvider: OceanDataProviding {
    let configuration: APIEnvironment
    // Live NIFS reports provide observed regions rather than exact points. They are modeled
    // as regional estimates rather than exact observations.
    let predictionUsesMockData = false
    var sourceLabel: String {
        "PUBLIC DATA MODEL"
    }

    func fetchBeaches() async throws -> [Beach] {
        var beaches = MockOceanDataProvider.beaches
        var configuredFeeds = 0
        var successfulFeeds = 0
        var latestFeedError: Error?
        let fetchedAt = Date()

        if let key = configuration.tourismKey {
            configuredFeeds += 1
            if let places = try? await TourismAPIClient(serviceKey: key).fetchGyeongbukPlaces() {
                beaches = beaches.map { beach in
                    guard let place = places.bestMatch(for: beach) else { return beach }
                    return beach.replacing(
                        latitude: place.latitude ?? beach.latitude,
                        longitude: place.longitude ?? beach.longitude,
                        address: place.address.isEmpty ? beach.address : place.address,
                        provenanceUpdates: Dictionary(uniqueKeysWithValues: [
                            place.latitude != nil && place.longitude != nil ? (.location, .live(source: "Korea Tourism Organization", fetchedAt: fetchedAt)) : nil,
                            !place.address.isEmpty ? (.address, .live(source: "Korea Tourism Organization", fetchedAt: fetchedAt)) : nil
                        ].compactMap { $0 })
                    )
                }
                successfulFeeds += 1
            }
        }

        if let key = configuration.kmaHubKey {
            configuredFeeds += 1
            if let observations = try? await KMAOceanClient(authKey: key).fetchLatest() {
                beaches = beaches.map { beach in
                    guard let observation = observations.bestMatch(for: beach) else { return beach }
                    let current = beach.marine
                    return beach.replacing(marine: MarineSnapshot(
                        waterTemperature: observation.waterTemperature ?? current.waterTemperature,
                        waveHeight: observation.waveHeight ?? current.waveHeight,
                        windSpeed: observation.windSpeed ?? current.windSpeed,
                        airTemperature: observation.airTemperature ?? current.airTemperature,
                        precipitation: current.precipitation,
                        currentDirection: current.currentDirection,
                        currentSpeed: current.currentSpeed
                    ), provenanceUpdates: Dictionary(uniqueKeysWithValues: [
                        observation.waterTemperature != nil ? (.waterTemperature, .live(source: "KMA Marine Observation", fetchedAt: fetchedAt)) : nil,
                        observation.waveHeight != nil ? (.waveHeight, .live(source: "KMA Marine Observation", fetchedAt: fetchedAt)) : nil,
                        observation.windSpeed != nil ? (.wind, .live(source: "KMA Marine Observation", fetchedAt: fetchedAt)) : nil,
                        observation.airTemperature != nil ? (.airTemperature, .live(source: "KMA Marine Observation", fetchedAt: fetchedAt)) : nil
                    ].compactMap { $0 }))
                }
                successfulFeeds += 1
            }
        }

        if let key = configuration.currentServiceKey,
           let endpoint = configuration.currentEndpoint {
            configuredFeeds += 1
            do {
                let currents = try await CurrentGridClient(serviceKey: key, endpoint: endpoint).fetchLatest()
                beaches = beaches.map { beach in
                    guard let current = currents.nearest(to: beach.coordinate) else { return beach }
                    let marine = beach.marine
                    return beach.replacing(marine: MarineSnapshot(
                        waterTemperature: marine.waterTemperature,
                        waveHeight: marine.waveHeight,
                        windSpeed: marine.windSpeed,
                        airTemperature: marine.airTemperature,
                        precipitation: marine.precipitation,
                        currentDirection: current.direction,
                        currentSpeed: current.speed
                    ), provenanceUpdates: [
                        .current: .live(source: "Public HF Radar Current", fetchedAt: fetchedAt)
                    ])
                }
                successfulFeeds += 1
            } catch {
                latestFeedError = error
            }
        }

        if let key = configuration.nifsKey {
            configuredFeeds += 1
            do {
                let bulletin = try await NIFSJellyfishClient(apiKey: key).fetchLatestBulletin()
                beaches = beaches.applying(bulletin: bulletin)
                successfulFeeds += 1
            } catch {
                latestFeedError = error
            }
        }

        if configuredFeeds > 0 && successfulFeeds == 0 {
            throw latestFeedError ?? LiveAPIError.noBeachFeedResponded
        }
        return beaches
    }

    func fetchTracks() async throws -> [JellyfishTrack] {
        guard let key = configuration.nifsKey else { return MockOceanDataProvider.modeledTracks }
        let bulletin = try await NIFSJellyfishClient(apiKey: key).fetchLatestBulletin()
        guard !bulletin.observations.isEmpty else { throw LiveAPIError.emptyJellyfishReport }
        let referenceDate = Date()

        let oceanObservations: [KMAOceanObservation]
        if let key = configuration.kmaHubKey {
            oceanObservations = (try? await KMAOceanClient(authKey: key).fetchLatest()) ?? []
        } else {
            oceanObservations = []
        }

        let gridCurrents: [GridCurrent]
        if let key = configuration.currentServiceKey, let endpoint = configuration.currentEndpoint {
            gridCurrents = (try? await CurrentGridClient(serviceKey: key, endpoint: endpoint).fetchLatest()) ?? []
        } else {
            gridCurrents = []
        }

        let marineForecasts: [KMAMarineForecastSample]
        if let key = configuration.kmaHubKey {
            marineForecasts = (try? await KMAMarineForecastClient(authKey: key)
                .fetchForecast(referenceDate: referenceDate)) ?? []
        } else {
            marineForecasts = []
        }

        let romsForecasts: [ROMSForecastSample]
        if let key = configuration.romsServiceKey, let endpoint = configuration.romsEndpoint {
            romsForecasts = (try? await ROMSForecastClient(serviceKey: key, endpoint: endpoint)
                .fetchGyeongbuk(referenceDate: referenceDate)) ?? []
        } else {
            romsForecasts = []
        }

        let tidalForecasts: [TidalCurrentSample]
        if let key = configuration.tidalCurrentServiceKey,
           let endpoint = configuration.tidalCurrentEndpoint {
            tidalForecasts = (try? await TidalCurrentClient(serviceKey: key, endpoint: endpoint)
                .fetchGyeongbuk(referenceDate: referenceDate)) ?? []
        } else {
            tidalForecasts = []
        }

        let engine = JellyfishPredictionEngine()
        return bulletin.observations.enumerated().map { index, regionalObservation in
            let origin = regionalObservation.seed.coordinate
            let species = regionalObservation.species.englishName
            let referenceBeach = MockOceanDataProvider.beaches.min {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
                < CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                    .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
            } ?? MockOceanDataProvider.beaches[0]
            let observedOcean = oceanObservations.bestMatch(for: referenceBeach)
            let observedCurrent = gridCurrents.nearest(to: origin)
            let hasROMSForecast = !romsForecasts.isEmpty
            let hasMarineForecast = !marineForecasts.isEmpty
            let hasTidalForecast = !tidalForecasts.isEmpty
            let usesFallbackForcing = (!hasROMSForecast && !hasTidalForecast && observedCurrent == nil)
                || (!hasMarineForecast && (
                    observedOcean?.windDirection == nil
                        || observedOcean?.windSpeed == nil
                        || observedOcean?.waveHeight == nil
                ))
            let fieldSamples = Self.fieldSamples(
                around: origin,
                referenceBeach: referenceBeach,
                oceanObservations: oceanObservations,
                gridCurrents: gridCurrents,
                marineForecasts: marineForecasts,
                romsForecasts: romsForecasts,
                tidalForecasts: tidalForecasts,
                referenceDate: referenceDate
            )
            let result = engine.predict(
                observation: JellyfishObservation(
                    coordinate: origin,
                    species: species,
                    initialUncertaintyRadius: regionalObservation.seed.uncertaintyRadius
                ),
                field: SpatiotemporalOceanField(samples: fieldSamples),
                coastline: GyeongbukCoastline.mask,
                seed: UInt64(20_260_822 + index * 10_007)
            )
            var backcastEngine = engine
            backcastEngine.forecastHours = Self.demoBackcastHours(
                observedAt: bulletin.report.observedDate,
                referenceDate: referenceDate
            )
            backcastEngine.checkpointHours = 6
            let backcastField = SpatiotemporalOceanField(
                samples: fieldSamples,
                temporalPolicy: .boundedPersistence(validHours: 0...backcastEngine.forecastHours)
            )
            let backcast = backcastEngine.backcast(
                observation: JellyfishObservation(
                    coordinate: origin,
                    species: species,
                    initialUncertaintyRadius: regionalObservation.seed.uncertaintyRadius
                ),
                field: backcastField,
                coastline: GyeongbukCoastline.mask,
                seed: UInt64(20_260_822 + index * 10_007 + 4_099)
            )
            let historicalPoints = backcast.points.filter { $0.hour < 0 }
            return JellyfishTrack(
                id: "nifs-\(regionalObservation.species.slug)-\(regionalObservation.seed.slug)",
                species: species,
                observedAt: "NIFS \(bulletin.report.dateText) · \(regionalObservation.seed.displayName) \(regionalObservation.density.englishName)",
                originKind: .officialRegionEstimate,
                checkpoints: historicalPoints.map { ($0.hour, $0.coordinate) }
                    + result.points.map { ($0.hour, $0.coordinate) },
                uncertaintyRadii: Dictionary(uniqueKeysWithValues:
                    historicalPoints.map { ($0.hour, $0.uncertaintyRadius) }
                        + result.points.map { ($0.hour, $0.uncertaintyRadius) }
                ),
                particleSnapshots: Dictionary(uniqueKeysWithValues: result.points.map { ($0.hour, $0.particles) }),
                provenance: .live(
                    source: usesFallbackForcing
                        ? "NIFS regional observation + demo ocean forcing"
                        : (hasROMSForecast || hasTidalForecast) && hasMarineForecast
                            ? "NIFS regional estimate + KHOA tidal/ROMS + KMA forecast"
                            : "NIFS + mixed live ocean forcing with partial persistence",
                    observedAt: bulletin.report.observedDate,
                    quality: usesFallbackForcing ? .mock : .derived,
                    spatialUncertaintyMeters: regionalObservation.seed.uncertaintyRadius
                )
            )
        }
    }

    private static func demoBackcastHours(observedAt: Date?, referenceDate: Date) -> Double {
        guard let observedAt else { return 24 }
        let elapsed = referenceDate.timeIntervalSince(observedAt) / 3_600
        // The demo slider exposes up to 75 hours. Keep a useful minimum trail when
        // a bulletin date has day precision and was published earlier today.
        return min(max(ceil(elapsed / 6) * 6, 24), 75)
    }

    private static func fieldSamples(
        around origin: CLLocationCoordinate2D,
        referenceBeach: Beach,
        oceanObservations: [KMAOceanObservation],
        gridCurrents: [GridCurrent],
        marineForecasts: [KMAMarineForecastSample],
        romsForecasts: [ROMSForecastSample],
        tidalForecasts: [TidalCurrentSample],
        referenceDate: Date
    ) -> [OceanFieldSample] {
        let relevantROMS = romsForecasts.filter {
            let hour = $0.date.timeIntervalSince(referenceDate) / 3_600
            return (-3...27).contains(hour)
        }
        if !relevantROMS.isEmpty {
            return relevantROMS.map { current in
                let nearestBeach = MockOceanDataProvider.beaches.nearest(to: current.coordinate) ?? referenceBeach
                let observedOcean = oceanObservations.bestMatch(for: nearestBeach)
                let marine = marineForecasts.nearest(to: current.coordinate, at: current.date)
                let tidal = tidalForecasts.nearest(to: current.coordinate, at: current.date)
                let fused = fusedCurrent(roms: current, tidal: tidal)
                return OceanFieldSample(
                    coordinate: current.coordinate,
                    hour: current.date.timeIntervalSince(referenceDate) / 3_600,
                    forcing: OceanForcing(
                        currentDirection: fused.direction,
                        currentSpeed: fused.speed,
                        windDirection: marine?.windDirection
                            ?? observedOcean?.windDirection ?? nearestBeach.marine.currentDirection + 35,
                        windSpeed: marine?.windSpeed
                            ?? observedOcean?.windSpeed ?? nearestBeach.marine.windSpeed,
                        waveHeight: marine?.waveHeight
                            ?? observedOcean?.waveHeight ?? nearestBeach.marine.waveHeight,
                        waterTemperature: current.waterTemperature
                    )
                )
            }
        }


        if !tidalForecasts.isEmpty {
            return tidalForecasts.map { current in
                let nearestBeach = MockOceanDataProvider.beaches.nearest(to: current.coordinate) ?? referenceBeach
                let observedOcean = oceanObservations.bestMatch(for: nearestBeach)
                let marine = marineForecasts.nearest(to: current.coordinate, at: current.date)
                return OceanFieldSample(
                    coordinate: current.coordinate,
                    hour: current.date.timeIntervalSince(referenceDate) / 3_600,
                    forcing: OceanForcing(
                        currentDirection: current.direction,
                        currentSpeed: current.speed,
                        windDirection: marine?.windDirection
                            ?? observedOcean?.windDirection ?? nearestBeach.marine.currentDirection + 35,
                        windSpeed: marine?.windSpeed
                            ?? observedOcean?.windSpeed ?? nearestBeach.marine.windSpeed,
                        waveHeight: marine?.waveHeight
                            ?? observedOcean?.waveHeight ?? nearestBeach.marine.waveHeight,
                        waterTemperature: marine?.waterTemperature
                            ?? observedOcean?.waterTemperature ?? nearestBeach.marine.waterTemperature
                    )
                )
            }
        }

        let currents = gridCurrents.isEmpty
            ? [GridCurrent(
                coordinate: origin,
                direction: referenceBeach.marine.currentDirection,
                speed: referenceBeach.marine.currentSpeed
            )]
            : gridCurrents
        let forecastHours = marineForecasts.isEmpty
            ? [0.0, 6.0, 12.0, 24.0]
            : Array(Set(marineForecasts.map { $0.date.timeIntervalSince(referenceDate) / 3_600 })).sorted()
        return currents.flatMap { current in
            let nearestBeach = MockOceanDataProvider.beaches.nearest(to: current.coordinate) ?? referenceBeach
            let ocean = oceanObservations.bestMatch(for: nearestBeach)
            return forecastHours.map { hour in
                let date = referenceDate.addingTimeInterval(hour * 3_600)
                let marine = marineForecasts.nearest(to: current.coordinate, at: date)
                return OceanFieldSample(
                    coordinate: current.coordinate,
                    hour: hour,
                    forcing: OceanForcing(
                        currentDirection: current.direction,
                        currentSpeed: current.speed,
                        windDirection: marine?.windDirection
                            ?? ocean?.windDirection ?? nearestBeach.marine.currentDirection + 35,
                        windSpeed: marine?.windSpeed ?? ocean?.windSpeed ?? nearestBeach.marine.windSpeed,
                        waveHeight: marine?.waveHeight ?? ocean?.waveHeight ?? nearestBeach.marine.waveHeight,
                        waterTemperature: marine?.waterTemperature
                            ?? ocean?.waterTemperature ?? nearestBeach.marine.waterTemperature
                    )
                )
            }
        }
    }

    private static func fusedCurrent(
        roms: ROMSForecastSample, tidal: TidalCurrentSample?
    ) -> (direction: Double, speed: Double) {
        guard let tidal else { return (roms.direction, roms.speed) }
        func vector(direction: Double, speed: Double) -> (east: Double, north: Double) {
            let radians = direction * .pi / 180
            return (speed * sin(radians), speed * cos(radians))
        }
        let background = vector(direction: roms.direction, speed: roms.speed)
        let nearshore = vector(direction: tidal.direction, speed: tidal.speed)
        // TidalCurrentArea is the higher-resolution nearshore signal; ROMS keeps
        // the broader residual-current tendency without double-counting it fully.
        let east = nearshore.east * 0.7 + background.east * 0.3
        let north = nearshore.north * 0.7 + background.north * 0.3
        let direction = (atan2(east, north) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        return (direction, hypot(east, north))
    }
}

private enum LiveAPIError: LocalizedError {
    case invalidURL, invalidResponse, noBeachFeedResponded, emptyJellyfishReport

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The public-data endpoint URL is invalid."
        case .invalidResponse: "The public-data service returned an invalid response."
        case .noBeachFeedResponded: "No configured beach or ocean feed responded."
        case .emptyJellyfishReport: "NIFS returned no recent jellyfish report."
        }
    }
}

private struct NIFSReport {
    let code: String
    let title: String
    let dateText: String
    let bulletinType: String

    var observedDate: Date? {
        let digits = dateText.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: String(digits.prefix(8)))
    }
}

enum NIFSSpecies: String, CaseIterable, Hashable {
    case nomura, moon, ghost, chrysaora, twoLightMoon, blueButton

    var koreanName: String {
        switch self {
        case .nomura: "노무라입깃해파리"
        case .moon: "보름달물해파리"
        case .ghost: "유령해파리류"
        case .chrysaora: "커튼원양해파리"
        case .twoLightMoon: "두빛보름달해파리"
        case .blueButton: "푸른우산관해파리"
        }
    }

    var englishName: String {
        switch self {
        case .nomura: "Nomura's jellyfish"
        case .moon: "Moon jellyfish"
        case .ghost: "Ghost jellyfish"
        case .chrysaora: "Sea nettle"
        case .twoLightMoon: "Two-light moon jellyfish"
        case .blueButton: "Blue button"
        }
    }

    var toxicity: String {
        switch self {
        case .nomura, .ghost, .chrysaora, .twoLightMoon: "강독성"
        case .moon, .blueButton: "약독성"
        }
    }

    var slug: String { rawValue }
}

enum NIFSDensity: Int, Hashable {
    case low = 0
    case high = 1

    var englishName: String { self == .high ? "HIGH DENSITY" : "LOW DENSITY" }
    var risk: RiskLevel { self == .high ? .later : .caution }
}

struct NIFSRegionSeed: Hashable {
    let slug: String
    let displayName: String
    let coordinate: CLLocationCoordinate2D
    /// Approximate 80% containment radius for a report that only names this region.
    let uncertaintyRadius: Double

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.slug == rhs.slug }
    func hash(into hasher: inout Hasher) { hasher.combine(slug) }
}

struct NIFSRegionalObservation: Hashable {
    let species: NIFSSpecies
    let density: NIFSDensity
    let seed: NIFSRegionSeed
}

private struct NIFSBulletin {
    let report: NIFSReport
    let observations: [NIFSRegionalObservation]
}

enum NIFSRegionSeedResolver {
    // Offshore representative points are deliberately paired with wide uncertainty radii.
    // They locate an official named observation area; they are not claimed as exact sightings.
    static let knownRegions: [(aliases: [String], seed: NIFSRegionSeed)] = [
        (["영일만"], .init(slug: "yeongil-bay", displayName: "영일만", coordinate: .init(latitude: 36.075, longitude: 129.475), uncertaintyRadius: 9_000)),
        (["구룡포항", "구룡포"], .init(slug: "guryongpo", displayName: "구룡포", coordinate: .init(latitude: 35.990, longitude: 129.575), uncertaintyRadius: 7_000)),
        (["월포"], .init(slug: "wolpo", displayName: "월포", coordinate: .init(latitude: 36.205, longitude: 129.445), uncertaintyRadius: 6_000)),
        (["감포"], .init(slug: "gampo", displayName: "감포", coordinate: .init(latitude: 35.805, longitude: 129.590), uncertaintyRadius: 8_000)),
        (["포항시", "포항"], .init(slug: "pohang-city", displayName: "포항시 연안", coordinate: .init(latitude: 36.100, longitude: 129.500), uncertaintyRadius: 22_000)),
        (["영덕군", "영덕"], .init(slug: "yeongdeok-county", displayName: "영덕군 연안", coordinate: .init(latitude: 36.480, longitude: 129.520), uncertaintyRadius: 32_000)),
        (["울진군", "울진"], .init(slug: "uljin-county", displayName: "울진군 연안", coordinate: .init(latitude: 36.880, longitude: 129.550), uncertaintyRadius: 40_000)),
        (["경주시", "경주"], .init(slug: "gyeongju-city", displayName: "경주시 연안", coordinate: .init(latitude: 35.800, longitude: 129.590), uncertaintyRadius: 28_000))
    ]

    static func resolve(line: String) -> NIFSRegionSeed? {
        knownRegions.first { entry in entry.aliases.contains { line.contains($0) } }?.seed
    }
}

enum NIFSJellyfishPDFParser {
    static func observations(from text: String) -> [NIFSRegionalObservation] {
        var isTrendSection = false
        var activeSpecies: NIFSSpecies?
        var activeDensity: NIFSDensity?
        var observations: [NIFSRegionalObservation] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.contains("■ 해파리 주간 동향") { isTrendSection = true; continue }
            if line.contains("□ 해파리 웹") { break }
            guard isTrendSection else { continue }

            if let species = NIFSSpecies.allCases.first(where: { line.contains($0.koreanName) }) {
                activeSpecies = species
                activeDensity = nil
            }
            if line.contains("고밀도 출현 해역") { activeDensity = .high }
            if line.contains("저밀도 출현 해역") { activeDensity = .low }

            guard line.contains("경북"),
                  let species = activeSpecies,
                  let density = activeDensity,
                  let seed = NIFSRegionSeedResolver.resolve(line: line) else { continue }
            observations.append(.init(species: species, density: density, seed: seed))
        }

        var bestBySpeciesAndRegion: [String: NIFSRegionalObservation] = [:]
        for observation in observations {
            let key = "\(observation.species.slug)-\(observation.seed.slug)"
            if let previous = bestBySpeciesAndRegion[key], previous.density.rawValue >= observation.density.rawValue {
                continue
            }
            bestBySpeciesAndRegion[key] = observation
        }
        return bestBySpeciesAndRegion.values.sorted {
            if $0.seed.displayName == $1.seed.displayName { return $0.species.slug < $1.species.slug }
            return $0.seed.displayName < $1.seed.displayName
        }
    }
}

private struct NIFSJellyfishClient {
    let apiKey: String

    func fetchLatestBulletin() async throws -> NIFSBulletin {
        let reports = try await fetchRecentReports()
        guard let report = reports.first(where: { $0.bulletinType == "0" }) ?? reports.first else {
            throw LiveAPIError.emptyJellyfishReport
        }

        var components = URLComponents(string: "https://www.nifs.go.kr/OpenAPI_json")
        components?.queryItems = [
            URLQueryItem(name: "id", value: "jellyDetail"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "srcode", value: report.code)
        ]
        guard let url = components?.url else { throw LiveAPIError.invalidURL }
        let object = try await NetworkLoader.json(from: url)
        guard let fileText = JSONWalker.dictionaries(in: object)
            .compactMap({ $0.string(for: ["board_file"]) }).first,
              let fileURL = URL(string: fileText) else { throw LiveAPIError.emptyJellyfishReport }
        let pdfData = try await NetworkLoader.data(from: fileURL)
        guard let text = PDFDocument(data: pdfData)?.string else { throw LiveAPIError.invalidResponse }
        let observations = NIFSJellyfishPDFParser.observations(from: text)
        guard !observations.isEmpty else { throw LiveAPIError.emptyJellyfishReport }
        return NIFSBulletin(report: report, observations: observations)
    }

    private func fetchRecentReports() async throws -> [NIFSReport] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyyMMdd"

        var components = URLComponents(string: "https://www.nifs.go.kr/OpenAPI_json")
        components?.queryItems = [
            URLQueryItem(name: "id", value: "jellyList"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "sdate", value: formatter.string(from: Date().addingTimeInterval(-60 * 60 * 24 * 35))),
            URLQueryItem(name: "edate", value: formatter.string(from: Date()))
        ]
        guard let url = components?.url else { throw LiveAPIError.invalidURL }
        let object = try await NetworkLoader.json(from: url)
        return JSONWalker.dictionaries(in: object).compactMap { item in
            guard let code = item.string(for: ["board_idx", "srcode"]),
                  let title = item.string(for: ["board_subject", "subject"]), !title.isEmpty else { return nil }
            return NIFSReport(
                code: code,
                title: title,
                dateText: item.string(for: ["inpt_date", "rdate"]) ?? "",
                bulletinType: item.string(for: ["gbn"]) ?? "0"
            )
        }.sorted { $0.dateText > $1.dateText }
    }
}

private struct TourismPlace {
    let title: String
    let address: String
    let latitude: Double?
    let longitude: Double?
}

private struct TourismAPIClient {
    let serviceKey: String

    func fetchGyeongbukPlaces() async throws -> [TourismPlace] {
        var components = URLComponents(string: "https://apis.data.go.kr/B551011/KorService2/areaBasedList2")
        components?.queryItems = [
            URLQueryItem(name: "serviceKey", value: serviceKey),
            URLQueryItem(name: "MobileOS", value: "IOS"),
            URLQueryItem(name: "MobileApp", value: "JellyTracker"),
            URLQueryItem(name: "_type", value: "json"),
            URLQueryItem(name: "areaCode", value: "35"),
            URLQueryItem(name: "numOfRows", value: "1000"),
            URLQueryItem(name: "pageNo", value: "1")
        ]
        guard let url = components?.url else { throw LiveAPIError.invalidURL }
        let object = try await NetworkLoader.json(from: url)
        return JSONWalker.dictionaries(in: object).compactMap { item in
            guard let title = item.string(for: ["title"]), !title.isEmpty else { return nil }
            return TourismPlace(
                title: title,
                address: item.string(for: ["addr1"]) ?? "",
                latitude: item.double(for: ["mapy"]),
                longitude: item.double(for: ["mapx"])
            )
        }
    }
}

private struct KMAOceanObservation {
    let stationName: String
    let waveHeight: Double?
    let windDirection: Double?
    let windSpeed: Double?
    let waterTemperature: Double?
    let airTemperature: Double?
}

private struct KMAOceanClient {
    let authKey: String

    func fetchLatest() async throws -> [KMAOceanObservation] {
        var components = URLComponents(string: "https://apihub.kma.go.kr/api/typ01/url/sea_obs.php")
        components?.queryItems = [
            URLQueryItem(name: "stn", value: "0"),
            URLQueryItem(name: "help", value: "0"),
            URLQueryItem(name: "authKey", value: authKey)
        ]
        guard let url = components?.url else { throw LiveAPIError.invalidURL }
        let text = try await NetworkLoader.text(from: url)

        return text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard fields.count >= 10 else { return nil }
            return KMAOceanObservation(
                stationName: fields[2],
                waveHeight: Self.valid(fields[safe: 4]),
                windDirection: Self.valid(fields[safe: 5]),
                windSpeed: Self.valid(fields[safe: 6]),
                waterTemperature: Self.valid(fields[safe: 8]),
                airTemperature: Self.valid(fields[safe: 9])
            )
        }
    }

    private static func valid(_ value: String?) -> Double? {
        guard let value, let number = Double(value), number > -8 else { return nil }
        return number
    }
}

struct KMAMarineForecastSample {
    let date: Date
    let coordinate: CLLocationCoordinate2D
    let waveHeight: Double
    let waveDirection: Double
    /// Direction the wind transports surface particles toward. KMA WD is a meteorological FROM direction.
    let windDirection: Double
    let windSpeed: Double
    let waterTemperature: Double?
}

struct KMAMarineForecastClient {
    let authKey: String
    static let endpoint = "https://apihub.kma.go.kr/api/typ06/url/marine_small_zone.php"
    // Official 0.5-degree zones covering the Gyeongbuk coast from Gyeongju/Pohang to Uljin.
    static let gyeongbukLargeZones = [70, 76, 82, 87]

    func fetchForecast(referenceDate: Date) async throws -> [KMAMarineForecastSample] {
        let firstEffectiveDate = Self.floor(referenceDate, intervalHours: 3)
        let latestCycle = Self.floor(referenceDate, intervalHours: 12)

        for cycleOffset in [0.0, -12, -24, -36] {
            let cycle = latestCycle.addingTimeInterval(cycleOffset * 3_600)
            guard let first = try? await fetch(cycle: cycle, effectiveDate: firstEffectiveDate), !first.isEmpty else {
                continue
            }
            let remainingDates = [6.0, 12, 18, 24].map {
                firstEffectiveDate.addingTimeInterval($0 * 3_600)
            }
            var combined = first
            await withTaskGroup(of: [KMAMarineForecastSample].self) { group in
                for date in remainingDates {
                    group.addTask { (try? await fetch(cycle: cycle, effectiveDate: date)) ?? [] }
                }
                for await samples in group { combined.append(contentsOf: samples) }
            }
            guard !combined.isEmpty else { continue }
            return combined.sorted { $0.date < $1.date }
        }
        throw LiveAPIError.invalidResponse
    }

    func requestURL(cycle: Date, effectiveDate: Date) throws -> URL {
        var components = URLComponents(string: Self.endpoint)
        components?.queryItems = [
            .init(name: "tma_fc", value: Self.utcFormatter.string(from: cycle)),
            .init(name: "tma_ef", value: Self.utcFormatter.string(from: effectiveDate)),
            .init(name: "Lzone", value: Self.gyeongbukLargeZones.map(String.init).joined(separator: ",")),
            .init(name: "Szone", value: "0"),
            .init(name: "disp", value: "0"),
            .init(name: "help", value: "0"),
            .init(name: "authKey", value: authKey)
        ]
        guard let url = components?.url else { throw LiveAPIError.invalidURL }
        return url
    }

    static func parse(_ text: String) -> [KMAMarineForecastSample] {
        text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard fields.count >= 17,
                  let date = utcFormatter.date(from: fields[1]),
                  let latitudeBottomLeft = valid(fields[4]), let longitudeBottomLeft = valid(fields[5]),
                  let latitudeTopLeft = valid(fields[6]), let longitudeTopLeft = valid(fields[7]),
                  let latitudeTopRight = valid(fields[8]), let longitudeTopRight = valid(fields[9]),
                  let latitudeBottomRight = valid(fields[10]), let longitudeBottomRight = valid(fields[11]),
                  let waveHeight = valid(fields[12]), let waveDirection = valid(fields[14]),
                  let windSpeed = valid(fields[15]), let meteorologicalWindDirection = valid(fields[16])
            else { return nil }
            let latitudes = [latitudeBottomLeft, latitudeTopLeft, latitudeTopRight, latitudeBottomRight]
            let longitudes = [longitudeBottomLeft, longitudeTopLeft, longitudeTopRight, longitudeBottomRight]
            return KMAMarineForecastSample(
                date: date,
                coordinate: .init(
                    latitude: ((latitudes.min() ?? latitudeBottomLeft) + (latitudes.max() ?? latitudeTopLeft)) / 2,
                    longitude: ((longitudes.min() ?? longitudeBottomLeft) + (longitudes.max() ?? longitudeTopRight)) / 2
                ),
                waveHeight: waveHeight,
                waveDirection: waveDirection,
                windDirection: (meteorologicalWindDirection + 180).truncatingRemainder(dividingBy: 360),
                windSpeed: windSpeed,
                waterTemperature: valid(fields[safe: 19])
            )
        }
    }

    private func fetch(cycle: Date, effectiveDate: Date) async throws -> [KMAMarineForecastSample] {
        let samples = Self.parse(try await NetworkLoader.text(from: requestURL(cycle: cycle, effectiveDate: effectiveDate)))
        guard !samples.isEmpty else { throw LiveAPIError.invalidResponse }
        return samples
    }

    private static func floor(_ date: Date, intervalHours: Double) -> Date {
        let interval = intervalHours * 3_600
        return Date(timeIntervalSince1970: Foundation.floor(date.timeIntervalSince1970 / interval) * interval)
    }

    private static func valid(_ value: String?) -> Double? {
        guard let value, let number = Double(value), number > -900 else { return nil }
        return number
    }

    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHH"
        return formatter
    }()
}

struct ROMSForecastSample {
    let date: Date
    let coordinate: CLLocationCoordinate2D
    let direction: Double
    let speed: Double
    let waterTemperature: Double
}

struct ROMSForecastClient {
    let serviceKey: String
    let endpoint: String
    static let referenceNodes = [
        CLLocationCoordinate2D(latitude: 36.10, longitude: 129.50),
        CLLocationCoordinate2D(latitude: 36.48, longitude: 129.52),
        CLLocationCoordinate2D(latitude: 36.88, longitude: 129.55)
    ]

    func fetchGyeongbuk(referenceDate: Date) async throws -> [ROMSForecastSample] {
        var combined: [ROMSForecastSample] = []
        await withTaskGroup(of: [ROMSForecastSample].self) { group in
            for coordinate in Self.referenceNodes {
                group.addTask { (try? await fetch(near: coordinate, referenceDate: referenceDate)) ?? [] }
            }
            for await samples in group { combined.append(contentsOf: samples) }
        }
        guard !combined.isEmpty else { throw LiveAPIError.invalidResponse }
        return combined
    }

    func requestURL(near coordinate: CLLocationCoordinate2D) throws -> URL {
        var normalizedEndpoint = endpoint
        if !normalizedEndpoint.hasSuffix("/GetRomsApiService") {
            normalizedEndpoint = normalizedEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                + "/GetRomsApiService"
        }
        var components = URLComponents(string: normalizedEndpoint)
        let margin = 0.025
        components?.queryItems = [
            .init(name: "serviceKey", value: serviceKey),
            .init(name: "type", value: "json"),
            .init(name: "ymin", value: String(coordinate.latitude - margin)),
            .init(name: "ymax", value: String(coordinate.latitude + margin)),
            .init(name: "xmin", value: String(coordinate.longitude - margin)),
            .init(name: "xmax", value: String(coordinate.longitude + margin)),
            .init(name: "pageNo", value: "1"),
            .init(name: "numOfRows", value: "300")
        ]
        if let encodedQuery = components?.percentEncodedQuery {
            components?.percentEncodedQuery = encodedQuery.replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components?.url else { throw LiveAPIError.invalidURL }
        return url
    }

    static func parse(_ object: Any, near target: CLLocationCoordinate2D, referenceDate: Date) -> [ROMSForecastSample] {
        let all = JSONWalker.dictionaries(in: object).compactMap { item -> ROMSForecastSample? in
            guard let dateText = item.string(for: ["predcDt"]),
                  let date = koreaFormatter.date(from: dateText),
                  let latitude = item.double(for: ["lat"]), let longitude = item.double(for: ["lot"]),
                  let direction = item.double(for: ["crdir"]), let speed = item.double(for: ["crsp"]),
                  let waterTemperature = item.double(for: ["wtem"])
            else { return nil }
            return ROMSForecastSample(
                date: date, coordinate: .init(latitude: latitude, longitude: longitude),
                direction: direction, speed: speed, waterTemperature: waterTemperature
            )
        }
        let relevant = all.filter {
            let hour = $0.date.timeIntervalSince(referenceDate) / 3_600
            return (-3...27).contains(hour)
        }
        let grouped = Dictionary(grouping: relevant) {
            String(format: "%.5f,%.5f", $0.coordinate.latitude, $0.coordinate.longitude)
        }
        return grouped.values.min {
            distance($0[0].coordinate, target) < distance($1[0].coordinate, target)
        }?.sorted { $0.date < $1.date } ?? []
    }

    private func fetch(near coordinate: CLLocationCoordinate2D, referenceDate: Date) async throws -> [ROMSForecastSample] {
        let samples = Self.parse(
            try await NetworkLoader.json(from: requestURL(near: coordinate)),
            near: coordinate,
            referenceDate: referenceDate
        )
        guard !samples.isEmpty else { throw LiveAPIError.invalidResponse }
        return samples
    }

    private static func distance(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }

    private static let koreaFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

struct TidalCurrentSample {
    let date: Date
    let coordinate: CLLocationCoordinate2D
    let direction: Double
    /// metres per second (the public API returns centimetres per second)
    let speed: Double
}

struct TidalCurrentClient {
    let serviceKey: String
    let endpoint: String

    func fetchGyeongbuk(referenceDate: Date) async throws -> [TidalCurrentSample] {
        var combined: [TidalCurrentSample] = []
        // The official field is a spatial grid for one instant. Three-hour frames
        // match the marine forecast cadence while keeping request use bounded.
        await withTaskGroup(of: [TidalCurrentSample].self) { group in
            for hour in stride(from: 0, through: 24, by: 3) {
                let date = referenceDate.addingTimeInterval(Double(hour) * 3_600)
                group.addTask { (try? await fetch(at: date)) ?? [] }
            }
            for await frame in group { combined.append(contentsOf: frame) }
        }
        guard !combined.isEmpty else { throw LiveAPIError.invalidResponse }
        return combined
    }

    func requestURL(at date: Date) throws -> URL {
        guard var components = URLComponents(string: endpoint) else { throw LiveAPIError.invalidURL }
        let parts = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let hour = parts.hour, let minute = parts.minute else { throw LiveAPIError.invalidURL }
        components.queryItems = [
            .init(name: "ServiceKey", value: serviceKey),
            .init(name: "Date", value: String(format: "%04d%02d%02d", year, month, day)),
            .init(name: "Hour", value: String(format: "%02d", hour)),
            .init(name: "Minute", value: String(format: "%02d", (minute / 10) * 10)),
            .init(name: "MaxX", value: "129.90"),
            .init(name: "MinX", value: "129.30"),
            .init(name: "MaxY", value: "37.20"),
            .init(name: "MinY", value: "35.70"),
            .init(name: "ResultType", value: "json")
        ]
        guard let url = components.url else { throw LiveAPIError.invalidURL }
        return url
    }

    static func parse(_ object: Any, date: Date) -> [TidalCurrentSample] {
        JSONWalker.dictionaries(in: object).compactMap { item in
            guard let longitude = item.double(for: ["pre_lon"]),
                  let latitude = item.double(for: ["pre_lat"]),
                  let direction = item.double(for: ["current_dir"]),
                  let speedCentimetres = item.double(for: ["current_speed"]),
                  speedCentimetres >= 0 else { return nil }
            return TidalCurrentSample(
                date: date,
                coordinate: .init(latitude: latitude, longitude: longitude),
                direction: direction,
                speed: speedCentimetres / 100
            )
        }
    }

    private func fetch(at date: Date) async throws -> [TidalCurrentSample] {
        let samples = Self.parse(try await NetworkLoader.json(from: requestURL(at: date)), date: date)
        guard !samples.isEmpty else { throw LiveAPIError.invalidResponse }
        return samples
    }

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()
}

private extension Array where Element == TidalCurrentSample {
    func nearest(to coordinate: CLLocationCoordinate2D, at date: Date) -> TidalCurrentSample? {
        min {
            let lhsTime = abs($0.date.timeIntervalSince(date)) / 60
            let rhsTime = abs($1.date.timeIntervalSince(date)) / 60
            let lhsDistance = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) / 1_000
            let rhsDistance = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) / 1_000
            return lhsTime + lhsDistance < rhsTime + rhsDistance
        }
    }
}

struct GridCurrent {
    let coordinate: CLLocationCoordinate2D
    let direction: Double
    let speed: Double
}

struct CurrentGridClient {
    let serviceKey: String
    let endpoint: String
    static let gyeongbukStationCodes = ["HF_0071", "HF_0073"]

    func fetchLatest() async throws -> [GridCurrent] {
        // The public gateway can reject simultaneous calls from the same key.
        // Query sequentially and keep partial live coverage when one station is temporarily unavailable.
        var combined: [GridCurrent] = []
        for stationCode in Self.gyeongbukStationCodes {
            if let observations = try? await fetchLatest(stationCode: stationCode) {
                combined.append(contentsOf: observations)
            }
        }
        guard !combined.isEmpty else { throw LiveAPIError.invalidResponse }
        return combined
    }

    func requestURL(stationCode: String) throws -> URL {
        guard var components = URLComponents(string: endpoint) else { throw LiveAPIError.invalidURL }
        var query = components.queryItems ?? []
        if !query.contains(where: { $0.name.lowercased() == "servicekey" }) {
            query.append(URLQueryItem(name: "serviceKey", value: serviceKey))
        }
        query.removeAll { ["obscode", "typeof", "type", "numofrows", "pageno"].contains($0.name.lowercased()) }
        query.append(URLQueryItem(name: "obsCode", value: stationCode))
        query.append(URLQueryItem(name: "type", value: "json"))
        query.append(URLQueryItem(name: "numOfRows", value: "300"))
        query.append(URLQueryItem(name: "pageNo", value: "1"))
        components.queryItems = query
        // URLComponents may leave '+' literal even though public-data gateways parse it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw LiveAPIError.invalidURL }
        return url
    }

    private func fetchLatest(stationCode: String) async throws -> [GridCurrent] {
        let url = try requestURL(stationCode: stationCode)
        let object = try await NetworkLoader.json(from: url)
        let observations = Self.parse(object)
        guard !observations.isEmpty else { throw LiveAPIError.invalidResponse }
        return observations
    }

    static func parse(_ object: Any) -> [GridCurrent] {
        JSONWalker.dictionaries(in: object).compactMap { item in
            guard let latitude = item.double(for: ["lat", "latitude", "위도"]),
                  let longitude = item.double(for: ["lot", "longitude", "lon", "경도"]),
                  let direction = item.double(for: ["crdir", "current direction", "currentDirection", "유향"]),
                  let speedCentimetersPerSecond = item.double(for: ["crsp", "current speed", "currentSpeed", "유속"]) else { return nil }
            return GridCurrent(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                direction: direction,
                speed: speedCentimetersPerSecond / 100
            )
        }
    }
}

private enum NetworkLoader {
    static func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadRevalidatingCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LiveAPIError.invalidResponse
        }
        return data
    }

    static func json(from url: URL) async throws -> Any {
        let payload = try await data(from: url)
        return try JSONSerialization.jsonObject(with: payload)
    }

    static func text(from url: URL) async throws -> String {
        let payload = try await data(from: url)
        guard let text = String(data: payload, encoding: .utf8) else { throw LiveAPIError.invalidResponse }
        return text
    }
}

private enum JSONWalker {
    nonisolated static func dictionaries(in object: Any) -> [[String: Any]] {
        if let dictionary = object as? [String: Any] {
            return [dictionary] + dictionary.values.flatMap(dictionaries)
        }
        if let array = object as? [Any] { return array.flatMap(dictionaries) }
        return []
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(for keys: [String]) -> String? {
        for key in keys {
            if let value = self[key] as? String { return value }
            if let value = self[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    func double(for keys: [String]) -> Double? {
        guard let value = string(for: keys) else { return nil }
        return Double(value)
    }
}

private extension Dictionary where Key == String, Value == String {
    func nonEmptyValue(for key: String) -> String? {
        guard let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == TourismPlace {
    func bestMatch(for beach: Beach) -> TourismPlace? {
        let target = beach.name.normalizedPlaceName
        return first { place in
            let candidate = place.title.normalizedPlaceName
            return candidate.contains(target) || target.contains(candidate)
        }
    }
}

private extension Array where Element == KMAOceanObservation {
    func bestMatch(for beach: Beach) -> KMAOceanObservation? {
        let preferredNames: [String]
        switch beach.city {
        case "포항시": preferredNames = ["포항", "구룡포"]
        case "영덕군": preferredNames = ["영덕", "울진", "포항"]
        case "울진군": preferredNames = ["울진", "죽변"]
        case "경주시": preferredNames = ["감포", "포항", "구룡포"]
        default: preferredNames = []
        }
        for name in preferredNames {
            if let match = first(where: { $0.stationName.contains(name) }) { return match }
        }
        return first
    }
}

private extension Array where Element == GridCurrent {
    func nearest(to coordinate: CLLocationCoordinate2D) -> GridCurrent? {
        self.min {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            < CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }
}

private extension Array where Element == KMAMarineForecastSample {
    func nearest(to coordinate: CLLocationCoordinate2D, at date: Date) -> KMAMarineForecastSample? {
        self.min {
            let lhsTime = abs($0.date.timeIntervalSince(date))
            let rhsTime = abs($1.date.timeIntervalSince(date))
            if abs(lhsTime - rhsTime) > 60 { return lhsTime < rhsTime }
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return target.distance(from: CLLocation(
                latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude
            )) < target.distance(from: CLLocation(
                latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude
            ))
        }
    }
}

private extension Array where Element == Beach {
    func nearest(to coordinate: CLLocationCoordinate2D) -> Beach? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return self.min {
            target.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < target.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }
}

private extension Array where Element == Beach {
    func applying(bulletin: NIFSBulletin) -> [Beach] {
        map { beach in
            let beachLocation = CLLocation(latitude: beach.latitude, longitude: beach.longitude)
            let nearby = bulletin.observations.filter { observation in
                let seedLocation = CLLocation(
                    latitude: observation.seed.coordinate.latitude,
                    longitude: observation.seed.coordinate.longitude
                )
                return beachLocation.distance(from: seedLocation) <= observation.seed.uncertaintyRadius + 6_000
            }
            guard !nearby.isEmpty else { return beach }

            let strongestRisk = nearby.map(\.density.risk).max() ?? .caution
            let strongestToxicity = nearby.contains { $0.species.toxicity == "강독성" } ? "강독성" : "약독성"
            let species = nearby.map(\.species.koreanName).uniqued().joined(separator: " · ")
            let regions = nearby.map(\.seed.displayName).uniqued().joined(separator: " · ")
            return beach.replacing(
                recentJellyfish: true,
                lastObservation: "NIFS \(bulletin.report.dateText) · \(regions) 공식 관측지역",
                species: species,
                toxicity: strongestToxicity,
                baseRisk: strongestRisk,
                provenanceUpdates: [
                    .jellyfishSightings: .live(
                        source: "NIFS Weekly Jellyfish Bulletin",
                        observedAt: bulletin.report.observedDate,
                        quality: .officialRegional,
                        spatialUncertaintyMeters: nearby.map(\.seed.uncertaintyRadius).max()
                    ),
                    .species: .live(source: "NIFS Weekly Jellyfish Bulletin", observedAt: bulletin.report.observedDate, quality: .officialRegional),
                    .toxicity: .live(source: "NIFS Weekly Jellyfish Bulletin", observedAt: bulletin.report.observedDate, quality: .officialRegional),
                    .baseRisk: .live(source: "NIFS-derived regional density", observedAt: bulletin.report.observedDate, quality: .derived)
                ]
            )
        }
    }
}

private extension String {
    var normalizedPlaceName: String {
        replacingOccurrences(of: "해수욕장", with: "")
            .replacingOccurrences(of: "해변", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

private extension Beach {
    func replacing(
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        marine: MarineSnapshot? = nil,
        recentJellyfish: Bool? = nil,
        lastObservation: String? = nil,
        species: String? = nil,
        toxicity: String? = nil,
        baseRisk: RiskLevel? = nil,
        provenanceUpdates: [BeachDataField: DataProvenance] = [:]
    ) -> Beach {
        let updatedMockFields = mockFields.subtracting(Set(provenanceUpdates.keys))
        let updatedProvenance = fieldProvenance.merging(provenanceUpdates) { _, new in new }
        return Beach(
            id: id, name: name, city: city,
            latitude: latitude ?? self.latitude,
            longitude: longitude ?? self.longitude,
            summary: summary,
            address: address ?? self.address,
            facilities: facilities,
            recentJellyfish: recentJellyfish ?? self.recentJellyfish,
            lastObservation: lastObservation ?? self.lastObservation,
            species: species ?? self.species,
            toxicity: toxicity ?? self.toxicity,
            baseRisk: baseRisk ?? self.baseRisk,
            marine: marine ?? self.marine,
            activities: activities,
            mockFields: updatedMockFields,
            fieldProvenance: updatedProvenance
        )
    }
}
