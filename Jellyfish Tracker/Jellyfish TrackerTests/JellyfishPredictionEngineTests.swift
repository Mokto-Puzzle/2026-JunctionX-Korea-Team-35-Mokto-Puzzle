import XCTest
import CoreLocation
@testable import Jellyfish_Tracker

final class JellyfishPredictionEngineTests: XCTestCase {
    private let origin = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.4)

    func testKMAOceanObservationParsesLiveCSVColumns() throws {
        let response = """
        #START7777
        B, 202608230900, 22106, 포항, 129.78330000, 36.35000000, 0.4, 236, 3.0, 3.6, 28.2, 26.8, 1014.5, 92.0, ,=
        C, 202608230900, 22490, 월포, 129.40100000, 36.21620000, 0.3, -99, -99.0, -99.0, 27.2, -99.0, -99.0, -99.0, ,=
        """

        let observations = KMAOceanClient.parse(response)

        XCTAssertEqual(observations.count, 2)
        XCTAssertEqual(observations[0].stationName, "포항")
        XCTAssertEqual(observations[0].waveHeight, 0.4)
        XCTAssertEqual(observations[0].windDirection, 236)
        XCTAssertEqual(observations[0].windSpeed, 3.0)
        XCTAssertEqual(observations[0].waterTemperature, 28.2)
        XCTAssertEqual(observations[0].airTemperature, 26.8)
        XCTAssertEqual(observations[1].stationName, "월포")
        XCTAssertEqual(observations[1].waterTemperature, 27.2)
        XCTAssertNil(observations[1].windSpeed)
    }

    func testEastwardCurrentMovesCentroidApproximatelyExpectedDistance() throws {
        let engine = JellyfishPredictionEngine(particleCount: 1_000)
        let result = engine.predict(
            observation: JellyfishObservation(coordinate: origin, species: "Nomura's jellyfish"),
            forcing: OceanForcing(
                currentDirection: 90,
                currentSpeed: 1,
                windDirection: 0,
                windSpeed: 0,
                waveHeight: 0,
                waterTemperature: 20
            ),
            seed: 42
        )
        let sixHour = try XCTUnwrap(result.points.first { $0.hour == 6 })
        let distance = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: sixHour.coordinate.latitude, longitude: sixHour.coordinate.longitude))

        XCTAssertEqual(distance, 21_600, accuracy: 1_200)
        XCTAssertGreaterThan(sixHour.coordinate.longitude, origin.longitude)
        XCTAssertEqual(sixHour.coordinate.latitude, origin.latitude, accuracy: 0.01)
    }

    func testBackcastReversesForcingAndUsesNegativeHours() throws {
        var engine = JellyfishPredictionEngine(particleCount: 1_000)
        engine.forecastHours = 6
        engine.checkpointHours = 3
        let forcing = OceanForcing(
            currentDirection: 90,
            currentSpeed: 1,
            windDirection: 0,
            windSpeed: 0,
            waveHeight: 0,
            waterTemperature: 20
        )
        let result = engine.backcast(
            observation: JellyfishObservation(coordinate: origin, species: "Nomura's jellyfish"),
            field: .init(constant: forcing, around: origin),
            coastline: AllWaterMask(),
            seed: 42
        )
        let sixHoursAgo = try XCTUnwrap(result.points.first { $0.hour == -6 })

        XCTAssertEqual(result.points.map(\.hour), [-6, -3, 0])
        XCTAssertLessThan(sixHoursAgo.coordinate.longitude, origin.longitude)
        XCTAssertEqual(sixHoursAgo.coordinate.latitude, origin.latitude, accuracy: 0.01)
    }

    func testUncertaintyExpandsOverForecastHorizon() throws {
        let result = JellyfishPredictionEngine(particleCount: 800).predict(
            observation: JellyfishObservation(coordinate: origin, species: "Moon jellyfish"),
            forcing: OceanForcing(
                currentDirection: 180,
                currentSpeed: 0.35,
                windDirection: 30,
                windSpeed: 6,
                waveHeight: 1.4,
                waterTemperature: 24
            ),
            seed: 7
        )
        let initial = try XCTUnwrap(result.points.first)
        let final = try XCTUnwrap(result.points.last)
        XCTAssertGreaterThan(final.uncertaintyRadius, initial.uncertaintyRadius)
    }

    func testRegionalObservationStartsWithWideUncertainty() throws {
        let result = JellyfishPredictionEngine(particleCount: 2_000).predict(
            observation: JellyfishObservation(
                coordinate: origin,
                species: "Nomura's jellyfish",
                initialUncertaintyRadius: 22_000
            ),
            forcing: OceanForcing(
                currentDirection: 0,
                currentSpeed: 0,
                windDirection: 0,
                windSpeed: 0,
                waveHeight: 0,
                waterTemperature: 20
            ),
            seed: 20260820
        )
        let initial = try XCTUnwrap(result.points.first)
        XCTAssertEqual(initial.uncertaintyRadius, 22_000, accuracy: 1_600)
    }

    func testLatestNIFSPDFTextProducesGyeongbukRegionalSeeds() throws {
        let fixture = """
        ■ 해파리 주간 동향 (2026.08.14.~08.20.)
        노무라입깃해파리
        ○고밀도 출현 해역
        - 경북 포항시
        ○저밀도 출현 해역
        - 경북 영덕군
        보름달물해파리
        ○저밀도 출현 해역
        - 강원 동해시
        유령해파리류
        ○고밀도 출현 해역
        - 경북 포항시
        □ 해파리 웹(web) 신고
        """

        let observations = NIFSJellyfishPDFParser.observations(from: fixture)
        XCTAssertEqual(observations.count, 3)
        XCTAssertTrue(observations.contains { $0.species == .nomura && $0.seed.slug == "pohang-city" && $0.density == .high })
        XCTAssertTrue(observations.contains { $0.species == .nomura && $0.seed.slug == "yeongdeok-county" && $0.density == .low })
        XCTAssertTrue(observations.contains { $0.species == .ghost && $0.seed.slug == "pohang-city" && $0.density == .high })
    }

    func testPredictionIsDeterministicForSameSeed() throws {
        let engine = JellyfishPredictionEngine(particleCount: 200)
        let forcing = OceanForcing(
            currentDirection: 225,
            currentSpeed: 0.4,
            windDirection: 20,
            windSpeed: 3,
            waveHeight: 0.8,
            waterTemperature: 23
        )
        let first = engine.predict(
            observation: JellyfishObservation(coordinate: origin, species: "Nomura's jellyfish"),
            forcing: forcing,
            seed: 99
        )
        let second = engine.predict(
            observation: JellyfishObservation(coordinate: origin, species: "Nomura's jellyfish"),
            forcing: forcing,
            seed: 99
        )
        XCTAssertEqual(first.points.map(\.coordinate.latitude), second.points.map(\.coordinate.latitude))
        XCTAssertEqual(first.points.map(\.coordinate.longitude), second.points.map(\.coordinate.longitude))
        XCTAssertEqual(first.points.map(\.uncertaintyRadius), second.points.map(\.uncertaintyRadius))
    }

    func testHistoricalSliderUsesCheckpointTrailEvenWhenForecastParticlesExist() {
        let old = CLLocationCoordinate2D(latitude: 36.20, longitude: 129.60)
        let now = CLLocationCoordinate2D(latitude: 36.10, longitude: 129.50)
        let forecast = CLLocationCoordinate2D(latitude: 36.00, longitude: 129.40)
        let track = JellyfishTrack(
            id: "timeline", species: "test", observedAt: "now",
            checkpoints: [(-24, old), (0, now), (24, forecast)],
            particleSnapshots: [
                0: [.init(coordinate: now, isBeached: false)],
                24: [.init(coordinate: forecast, isBeached: false)]
            ]
        )

        let historical = track.coordinate(at: -12)
        XCTAssertEqual(historical.latitude, 36.15, accuracy: 0.0001)
        XCTAssertEqual(historical.longitude, 129.55, accuracy: 0.0001)
        XCTAssertNotEqual(historical.latitude, now.latitude)
        XCTAssertGreaterThan(track.uncertaintyRadius(at: -24), track.uncertaintyRadius(at: -1))
    }

    func testHistoricalSliderBackcastsWhenOfficialTrackHasNoPastCheckpoints() {
        let now = CLLocationCoordinate2D(latitude: 36.05, longitude: 129.48)
        let future = CLLocationCoordinate2D(latitude: 36.06, longitude: 129.49)
        let track = JellyfishTrack(
            id: "official", species: "test", observedAt: "now",
            checkpoints: [(0, now), (6, future)],
            particleSnapshots: [0: [.init(coordinate: now, isBeached: false)]]
        )

        let past = track.coordinate(at: -6)
        XCTAssertNotEqual(past.latitude, now.latitude)
        XCTAssertNotEqual(past.longitude, now.longitude)
        XCTAssertTrue(GyeongbukCoastline.mask.isWater(past))
        XCTAssertFalse(track.historyPath(at: -6).isEmpty)
    }

    func testHFCurrentOfficialResponseFieldsAndUnits() throws {
        let response: [String: Any] = [
            "response": [
                "body": [
                    "items": [[
                        "obsvtrNm": "포항항",
                        "lot": 129.45,
                        "lat": 36.05,
                        "crdir": 119.3,
                        "crsp": 20.17
                    ]]
                ]
            ]
        ]

        let result = CurrentGridClient.parse(response)
        let current = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(current.coordinate.longitude, 129.45, accuracy: 0.0001)
        XCTAssertEqual(current.coordinate.latitude, 36.05, accuracy: 0.0001)
        XCTAssertEqual(current.direction, 119.3, accuracy: 0.001)
        XCTAssertEqual(current.speed, 0.2017, accuracy: 0.0001)
    }

    func testHFCurrentRequestUsesOfficialParameters() throws {
        let client = CurrentGridClient(
            serviceKey: "test+key/value==",
            endpoint: APIEnvironment.defaultCurrentEndpoint
        )
        let url = try client.requestURL(stationCode: "HF_0071")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.path, "/1192136/hfCurrent/GetHFCurrentApiService")
        XCTAssertEqual(query["obsCode"], "HF_0071")
        XCTAssertEqual(query["type"], "json")
        XCTAssertEqual(query["numOfRows"], "300")
        XCTAssertEqual(query["pageNo"], "1")
        XCTAssertFalse(url.absoluteString.contains("test+key"))
        XCTAssertTrue(url.absoluteString.contains("test%2Bkey"))
    }

    func testReferenceValuesDoNotAddAlertPunctuation() throws {
        let beach = try XCTUnwrap(MockOceanDataProvider.beaches.first)
        XCTAssertEqual(beach.provenance(for: .waveHeight).quality, .mock)
        XCTAssertEqual(beach.marked("0.8 m", fields: .waveHeight), "0.8 m")

        var liveBeach = beach
        liveBeach.mockFields.remove(.waveHeight)
        liveBeach.fieldProvenance[.waveHeight] = .live(source: "KMA Marine Observation")
        XCTAssertEqual(liveBeach.marked("0.8 m", fields: .waveHeight), "0.8 m")
    }

    func testOfficialRegionalTrackIsNotMock() {
        let track = JellyfishTrack(
            id: "regional",
            species: "Nomura's jellyfish",
            observedAt: "NIFS report",
            originKind: .officialRegionEstimate,
            checkpoints: [(0, origin)],
            provenance: .live(
                source: "NIFS Weekly Jellyfish Bulletin",
                quality: .officialRegional,
                spatialUncertaintyMeters: 22_000
            )
        )
        XCTAssertEqual(track.provenance.quality, .officialRegional)
        XCTAssertNotEqual(track.provenance.quality, .mock)
        XCTAssertEqual(track.provenance.spatialUncertaintyMeters, 22_000)
    }

    func testSpatiotemporalFieldInterpolatesSpaceAndTime() throws {
        let west = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.3)
        let east = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.5)
        let calm = OceanForcing(
            currentDirection: 90, currentSpeed: 0,
            windDirection: 0, windSpeed: 0, waveHeight: 0, waterTemperature: 10
        )
        let moving = OceanForcing(
            currentDirection: 90, currentSpeed: 1,
            windDirection: 90, windSpeed: 10, waveHeight: 2, waterTemperature: 20
        )
        let field = SpatiotemporalOceanField(samples: [
            .init(coordinate: west, hour: 0, forcing: calm),
            .init(coordinate: east, hour: 0, forcing: calm),
            .init(coordinate: west, hour: 6, forcing: moving),
            .init(coordinate: east, hour: 6, forcing: moving)
        ])
        let value = try XCTUnwrap(field.forcing(at: origin, hour: 3))
        XCTAssertEqual(value.currentSpeed, 0.5, accuracy: 0.001)
        XCTAssertEqual(value.windSpeed, 5, accuracy: 0.001)
        XCTAssertEqual(value.waveHeight, 1, accuracy: 0.001)
        XCTAssertEqual(value.waterTemperature, 15, accuracy: 0.001)
    }

    func testOppositeVectorsInterpolateToSlackWater() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.4)
        let field = SpatiotemporalOceanField(samples: [
            .init(coordinate: coordinate, hour: 0, forcing: .init(
                currentDirection: 90, currentSpeed: 1,
                windDirection: 0, windSpeed: 8,
                waveHeight: 1, waterTemperature: 20
            )),
            .init(coordinate: coordinate, hour: 2, forcing: .init(
                currentDirection: 270, currentSpeed: 1,
                windDirection: 180, windSpeed: 8,
                waveHeight: 3, waterTemperature: 24
            ))
        ])

        let midpoint = try XCTUnwrap(field.forcing(at: coordinate, hour: 1))
        XCTAssertEqual(midpoint.currentSpeed, 0, accuracy: 1e-10)
        XCTAssertEqual(midpoint.windSpeed, 0, accuracy: 1e-10)
        XCTAssertEqual(midpoint.waveHeight, 2, accuracy: 1e-10)
    }

    func testPublishedOceanSamplesDoNotExtrapolateInTime() {
        let coordinate = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.4)
        let forcing = OceanForcing(
            currentDirection: 45, currentSpeed: 0.5,
            windDirection: 90, windSpeed: 3,
            waveHeight: 1.2, waterTemperature: 21
        )
        let field = SpatiotemporalOceanField(samples: [
            .init(coordinate: coordinate, hour: -6, forcing: forcing),
            .init(coordinate: coordinate, hour: 12, forcing: forcing)
        ])

        XCTAssertNil(field.forcing(at: coordinate, hour: -6.001))
        XCTAssertNotNil(field.forcing(at: coordinate, hour: -6))
        XCTAssertNotNil(field.forcing(at: coordinate, hour: 12))
        XCTAssertNil(field.forcing(at: coordinate, hour: 12.001))
    }

    func testConstantOceanFieldRemainsAvailableAcrossSimulation() {
        let coordinate = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.4)
        let field = SpatiotemporalOceanField(constant: .init(
            currentDirection: 90, currentSpeed: 0.4,
            windDirection: 0, windSpeed: 0,
            waveHeight: 0.5, waterTemperature: 20
        ), around: coordinate)

        XCTAssertNotNil(field.forcing(at: coordinate, hour: -75))
        XCTAssertNotNil(field.forcing(at: coordinate, hour: 24))
    }

    func testParticlesBeachAtLandBoundaryAndDoNotCrossLand() throws {
        struct WestIsLand: CoastlineMask {
            func isWater(_ coordinate: CLLocationCoordinate2D) -> Bool { coordinate.longitude >= 129.40 }
        }
        let start = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.41)
        let forcing = OceanForcing(
            currentDirection: 270, currentSpeed: 0.8,
            windDirection: 0, windSpeed: 0, waveHeight: 0, waterTemperature: 20
        )
        let result = JellyfishPredictionEngine(
            particleCount: 500, stepSeconds: 600, forecastHours: 3, checkpointHours: 1
        ).predict(
            observation: .init(coordinate: start, species: "Nomura's jellyfish"),
            field: .init(constant: forcing, around: start),
            coastline: WestIsLand(),
            seed: 11
        )
        let final = try XCTUnwrap(result.points.last)
        XCTAssertGreaterThan(final.beachedFraction, 0.8)
        XCTAssertTrue(final.particles.allSatisfy { $0.coordinate.longitude >= 129.3999 })
    }

    func testParticleIDsRemainStableAcrossPredictionFrames() throws {
        let start = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.41)
        let result = JellyfishPredictionEngine(
            particleCount: 40, stepSeconds: 600, forecastHours: 2, checkpointHours: 1
        ).predict(
            observation: .init(coordinate: start, species: "moon jellyfish"),
            forcing: .init(
                currentDirection: 90, currentSpeed: 0.2,
                windDirection: 0, windSpeed: 0,
                waveHeight: 0.5, waterTemperature: 20
            ),
            seed: 42
        )

        let expectedIDs = try XCTUnwrap(result.points.first).particles.map(\.id)
        XCTAssertEqual(Set(expectedIDs).count, expectedIDs.count)
        for point in result.points {
            XCTAssertEqual(point.particles.map(\.id), expectedIDs)
        }
    }

    func testUnsupportedForecastHourDoesNotReturnParticlesOrImpact() throws {
        let track = try XCTUnwrap(MockOceanDataProvider.modeledTracks.first)
        let unsupportedHour = track.supportedFutureHorizon + 1

        XCTAssertTrue(track.particles(at: unsupportedHour).isEmpty)
        XCTAssertNil(track.entryFraction(
            near: track.coordinate(at: 0),
            radius: 5_000,
            upTo: unsupportedHour
        ))
    }

    func testOfficialRegionalTrackDoesNotInventHistoricalPath() {
        let track = JellyfishTrack(
            id: "official-history",
            species: "Moon jellyfish",
            observedAt: "NIFS",
            originKind: .officialRegionEstimate,
            checkpoints: [(0, .init(latitude: 36.0, longitude: 129.5))],
            provenance: .live(source: "NIFS", quality: .officialRegional)
        )

        XCTAssertTrue(track.historyPath(at: -12).isEmpty)
    }

    func testParticleCannotTunnelAcrossNarrowLandWhenDestinationIsWater() throws {
        struct NarrowLandStrip: CoastlineMask {
            func isWater(_ coordinate: CLLocationCoordinate2D) -> Bool {
                !(129.405...129.415).contains(coordinate.longitude)
            }
        }
        let start = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.40)
        let forcing = OceanForcing(
            currentDirection: 90, currentSpeed: 1,
            windDirection: 0, windSpeed: 0, waveHeight: 0, waterTemperature: 20
        )
        let result = JellyfishPredictionEngine(
            particleCount: 200, stepSeconds: 3_600, forecastHours: 1, checkpointHours: 1
        ).predict(
            observation: .init(coordinate: start, species: "test", initialUncertaintyRadius: 350),
            field: .init(constant: forcing, around: start),
            coastline: NarrowLandStrip(),
            seed: 19
        )
        let final = try XCTUnwrap(result.points.last)
        XCTAssertGreaterThan(final.beachedFraction, 0.9)
        XCTAssertTrue(final.particles.allSatisfy { $0.coordinate.longitude < 129.4051 })
    }

    func testRegionalForecastTrackersAndParticlesRemainOnWater() throws {
        let seeds = [
            CLLocationCoordinate2D(latitude: 36.100, longitude: 129.500),
            CLLocationCoordinate2D(latitude: 36.480, longitude: 129.520),
            CLLocationCoordinate2D(latitude: 36.880, longitude: 129.550),
            CLLocationCoordinate2D(latitude: 35.800, longitude: 129.590)
        ]
        let forcing = OceanForcing(
            currentDirection: 245, currentSpeed: 0.35,
            windDirection: 45, windSpeed: 5, waveHeight: 1.2, waterTemperature: 24
        )

        for (index, seedCoordinate) in seeds.enumerated() {
            let result = JellyfishPredictionEngine(
                particleCount: 500, stepSeconds: 1_800, forecastHours: 24, checkpointHours: 3
            ).predict(
                observation: .init(
                    coordinate: seedCoordinate,
                    species: "Nomura's jellyfish",
                    initialUncertaintyRadius: 22_000
                ),
                field: .init(constant: forcing, around: seedCoordinate),
                coastline: GyeongbukCoastline.mask,
                seed: UInt64(2_026_082_300 + index)
            )
            XCTAssertTrue(result.points.allSatisfy { GyeongbukCoastline.mask.isWater($0.coordinate) })
            XCTAssertTrue(result.points.flatMap(\.particles).allSatisfy {
                GyeongbukCoastline.mask.isWater($0.coordinate)
            })

            let track = JellyfishTrack(
                id: "regional-\(index)", species: "Nomura's jellyfish", observedAt: "test",
                originKind: .officialRegionEstimate,
                checkpoints: result.points.map { ($0.hour, $0.coordinate) },
                particleSnapshots: Dictionary(uniqueKeysWithValues: result.points.map { ($0.hour, $0.particles) })
            )
            for hour in stride(from: 0.0, through: 24.0, by: 1.0) {
                XCTAssertTrue(GyeongbukCoastline.mask.isWater(track.coordinate(at: hour)))
            }
            XCTAssertTrue(track.forecastPath(at: 24).allSatisfy(GyeongbukCoastline.mask.isWater))
            XCTAssertTrue(JellyfishTrack.pathStaysInWater(track.forecastPath(at: 24, sampleIntervalHours: 3)))
        }
    }

    func testOfficialKHOACoastlineResourceClassifiesLandAndWater() {
        XCTAssertTrue(GyeongbukCoastline.usesOfficialData)
        XCTAssertTrue(GyeongbukCoastline.source.contains("KHOA"))
        XCTAssertGreaterThan(GyeongbukCoastline.mask.landPolygons.count, 4_000)
        XCTAssertFalse(GyeongbukCoastline.mask.isWater(.init(latitude: 36.50, longitude: 128.80)))
        XCTAssertTrue(GyeongbukCoastline.mask.isWater(.init(latitude: 36.50, longitude: 129.75)))
        XCTAssertTrue(GyeongbukCoastline.mask.isWater(.init(latitude: 36.05, longitude: 129.48)))
        XCTAssertTrue(GyeongbukCoastline.mask.isWater(.init(latitude: 36.90, longitude: 129.55)))
    }

    func testEntryFractionUsesParticleVisitsInsteadOfCentroidDistance() throws {
        let target = CLLocationCoordinate2D(latitude: 36.0, longitude: 129.4)
        let far = CLLocationCoordinate2D(latitude: 36.2, longitude: 129.7)
        let track = JellyfishTrack(
            id: "particles", species: "test", observedAt: "now",
            checkpoints: [(0, far), (6, far)],
            particleSnapshots: [
                0: [
                    .init(coordinate: target, isBeached: false),
                    .init(coordinate: far, isBeached: false)
                ],
                6: [
                    .init(coordinate: far, isBeached: false),
                    .init(coordinate: far, isBeached: false)
                ]
            ]
        )
        XCTAssertEqual(try XCTUnwrap(track.entryFraction(near: target, radius: 1_000, upTo: 6)), 0.5, accuracy: 0.001)
    }

    func testKMASmallZoneForecastParserAndWindDirectionConversion() throws {
        let fixture = """
        #START7777
        2026082212 2026082300 82 1 36.333 129.500 36.500 129.500 36.500 129.667 36.333 129.667 1.4 8.2 55.0 4.5 30.0 12000 0.0 26.7 1
        2026082212 2026082300 82 2 36.333 129.667 36.500 129.667 36.500 129.833 36.333 129.833 -999.0 -999.0 -999.0 -999.0 -999.0 -999.0 -999.0 -999.0 -999
        #7777END
        """
        let samples = KMAMarineForecastClient.parse(fixture)
        let sample = try XCTUnwrap(samples.first)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(sample.coordinate.latitude, 36.4165, accuracy: 0.0001)
        XCTAssertEqual(sample.coordinate.longitude, 129.5835, accuracy: 0.0001)
        XCTAssertEqual(sample.waveHeight, 1.4, accuracy: 0.001)
        XCTAssertEqual(sample.windDirection, 210, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(sample.waterTemperature), 26.7, accuracy: 0.001)
        XCTAssertEqual(KMAMarineForecastClient.gyeongbukLargeZones, [70, 76, 82, 87])
    }

    func testROMSForecastParserKeepsNearestGridAndFutureWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 23, hour: 0
        )))
        let object: [String: Any] = ["body": ["items": ["item": [
            ["predcDt": "2026-08-22 20:00:00", "lat": 36.04, "lot": 129.44, "crdir": 10, "crsp": 0.1, "wtem": 25],
            ["predcDt": "2026-08-23 00:00:00", "lat": 36.04, "lot": 129.44, "crdir": 20, "crsp": 0.2, "wtem": 26],
            ["predcDt": "2026-08-24 00:00:00", "lat": 36.04, "lot": 129.44, "crdir": 30, "crsp": 0.3, "wtem": 27],
            ["predcDt": "2026-08-23 00:00:00", "lat": 36.06, "lot": 129.46, "crdir": 40, "crsp": 0.4, "wtem": 28]
        ]]]]
        let samples = ROMSForecastClient.parse(
            object, near: .init(latitude: 36.041, longitude: 129.441), referenceDate: reference
        )
        XCTAssertEqual(samples.count, 2)
        XCTAssertTrue(samples.allSatisfy { $0.coordinate.latitude == 36.04 })
        XCTAssertEqual(try XCTUnwrap(samples.last).speed, 0.3, accuracy: 0.001)
    }

    func testTidalCurrentParserConvertsCentimetresPerSecond() throws {
        let date = Date(timeIntervalSince1970: 1_787_452_800)
        let object: [String: Any] = ["result": ["data": [[
            "current_speed": "15.0",
            "pre_lon": "129.50297",
            "current_dir": "195",
            "pre_lat": "35.70638"
        ]]]]
        let samples = TidalCurrentClient.parse(object, date: date)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(try XCTUnwrap(samples.first).speed, 0.15, accuracy: 0.000_1)
        XCTAssertEqual(try XCTUnwrap(samples.first).direction, 195, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(samples.first).coordinate.longitude, 129.50297, accuracy: 0.000_01)
    }

    func testTidalCurrentRequestUsesOfficialAreaParameters() throws {
        let client = TidalCurrentClient(
            serviceKey: "demo-key==",
            endpoint: APIEnvironment.defaultTidalCurrentEndpoint
        )
        let url = try client.requestURL(at: Date(timeIntervalSince1970: 1_787_452_800))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["ServiceKey"], "demo-key==")
        XCTAssertEqual(values["ResultType"], "json")
        XCTAssertEqual(values["MinX"], "129.30")
        XCTAssertEqual(values["MaxY"], "37.20")
    }
}
