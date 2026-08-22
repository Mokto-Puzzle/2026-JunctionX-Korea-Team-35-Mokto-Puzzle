import Foundation
import Combine
import MapKit
import SwiftUI

@MainActor
final class JellyMapViewModel: ObservableObject {
    @Published var beaches: [Beach] = []
    @Published var tracks: [JellyfishTrack] = []
    @Published var selectedLayers: Set<MapLayer> = [.predictedPath]
    @Published var forecastHour = 0.0
    @Published var searchText = ""
    @Published var selectedBeach: Beach?
    @Published var focusedBeach: Beach?
    @Published var position: MapCameraPosition = .region(JellyMapViewModel.fallbackRegion)
    @Published var isLoading = false
    @Published var dataError: String?
    @Published var lastUpdated = Date()
    @Published var dataSourceLabel = "REFERENCE DATA"
    @Published var predictionUsesMockData = true
    @Published var predictionUsesEstimatedOrigin = false

    private let provider: OceanDataProviding
    init(provider: OceanDataProviding? = nil) {
        let resolvedProvider = provider ?? OceanDataProviderFactory.make()
        self.provider = resolvedProvider
        dataSourceLabel = resolvedProvider.sourceLabel
        predictionUsesMockData = resolvedProvider.predictionUsesMockData
    }

    static let fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.42, longitude: 129.43),
        span: MKCoordinateSpan(latitudeDelta: 1.80, longitudeDelta: 0.95)
    )

    func load() async {
        isLoading = true
        dataError = nil
        defer { isLoading = false }

        var unavailableFeeds: [String] = []
        do {
            beaches = try await provider.fetchBeaches()
        } catch {
            beaches = MockOceanDataProvider.beaches
            unavailableFeeds.append("beach conditions: \(error.localizedDescription)")
        }
        do {
            tracks = try await provider.fetchTracks()
        } catch {
            tracks = MockOceanDataProvider.tracks
            unavailableFeeds.append("jellyfish routes")
        }
        lastUpdated = Date()
        dataSourceLabel = unavailableFeeds.isEmpty ? provider.sourceLabel : "REFERENCE DATA"
        predictionUsesMockData = tracks.contains { $0.provenance.quality == .mock }
            || unavailableFeeds.contains("jellyfish routes")
        predictionUsesEstimatedOrigin = tracks.contains { $0.originKind == .officialRegionEstimate }
        if !unavailableFeeds.isEmpty, beaches.isEmpty || tracks.isEmpty {
            dataError = "Data could not be prepared. Please refresh."
        }
    }

    var predictionNeedsMarker: Bool {
        predictionUsesMockData
    }

    var predictionQuality: DataQuality {
        if tracks.isEmpty { return .missing }
        let qualities = tracks.map { effectiveQuality(for: $0.provenance) }
        if qualities.contains(.mock) { return .mock }
        if qualities.contains(.missing) { return .missing }
        if qualities.contains(.stale) { return .stale }
        if qualities.contains(.officialRegional) { return .officialRegional }
        return .derived
    }

    var predictionBadge: String? { predictionQuality.badge }

    func quality(for beach: Beach, fields: BeachDataField...) -> DataQuality {
        let qualities = fields.map { effectiveQuality(for: beach.provenance(for: $0)) }
        if qualities.contains(.mock) { return .mock }
        if qualities.contains(.missing) { return .missing }
        if qualities.contains(.stale) { return .stale }
        if qualities.contains(.officialRegional) { return .officialRegional }
        if qualities.contains(.derived) { return .derived }
        return .officialExact
    }

    func provenanceText(for beach: Beach, field: BeachDataField) -> String {
        let provenance = beach.provenance(for: field)
        let quality = effectiveQuality(for: provenance)
        let date = provenance.observedAt ?? provenance.fetchedAt
        let timestamp = Self.provenanceDateFormatter.string(from: date)
        let uncertainty = provenance.spatialUncertaintyMeters.map { " · ±\(Int(($0 / 1_000).rounded())) km" } ?? ""
        return "\(quality.badge.map { "[\($0)] " } ?? "")\(provenance.source) · \(timestamp)\(uncertainty)"
    }

    func annotated(_ value: String, for beach: Beach, fields: BeachDataField...) -> String {
        switch quality(for: beach, fields: fields) {
        case .mock: return value
        case .missing: return "Check later"
        case .stale: return "\(value) · RECENT"
        case .officialRegional: return "\(value) · REGIONAL"
        case .derived, .officialExact: return value
        }
    }

    private func quality(for beach: Beach, fields: [BeachDataField]) -> DataQuality {
        let qualities = fields.map { effectiveQuality(for: beach.provenance(for: $0)) }
        if qualities.contains(.mock) { return .mock }
        if qualities.contains(.missing) { return .missing }
        if qualities.contains(.stale) { return .stale }
        if qualities.contains(.officialRegional) { return .officialRegional }
        if qualities.contains(.derived) { return .derived }
        return .officialExact
    }

    func trackProvenanceText(_ track: JellyfishTrack) -> String {
        let quality = effectiveQuality(for: track.provenance)
        let timestamp = Self.provenanceDateFormatter.string(from: track.provenance.timestamp)
        let uncertainty = track.provenance.spatialUncertaintyMeters.map { " · ±\(Int(($0 / 1_000).rounded())) km" } ?? ""
        return "\(quality.badge.map { "[\($0)] " } ?? "")\(track.provenance.source) · \(timestamp)\(uncertainty)"
    }

    private func effectiveQuality(for provenance: DataProvenance) -> DataQuality {
        guard ![DataQuality.mock, .missing].contains(provenance.quality) else { return provenance.quality }
        let age = Date().timeIntervalSince(provenance.timestamp)
        let limit: TimeInterval
        if provenance.source.contains("NIFS") { limit = 8 * 24 * 60 * 60 }
        else if provenance.source.contains("Tourism") { return provenance.quality }
        else { limit = 6 * 60 * 60 }
        return age > limit ? .stale : provenance.quality
    }

    func nearby(to coordinate: CLLocationCoordinate2D, count: Int = 4) -> [Beach] {
        beaches.sorted {
            distance(from: coordinate, to: $0.coordinate) < distance(from: coordinate, to: $1.coordinate)
        }.prefix(count).map { $0 }
    }

    func distance(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude)) / 1_000
    }

    func focusNearby(_ coordinate: CLLocationCoordinate2D) {
        focusedBeach = nil
        focus(on: nearby(to: coordinate).map(\.coordinate) + [coordinate])
    }

    func focus(on beach: Beach) {
        focusedBeach = beach
        position = .region(MKCoordinateRegion(
            center: beach.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.055, longitudeDelta: 0.045)
        ))
        selectedBeach = beach
    }

    func mapBeaches(around coordinate: CLLocationCoordinate2D) -> [Beach] {
        var result = nearby(to: coordinate)
        if let focusedBeach, !result.contains(where: { $0.id == focusedBeach.id }) {
            result.append(focusedBeach)
        }
        return result
    }

    private func focus(on coordinates: [CLLocationCoordinate2D]) {
        guard let first = coordinates.first else { return }
        let minLat = coordinates.map(\.latitude).min() ?? first.latitude
        let maxLat = coordinates.map(\.latitude).max() ?? first.latitude
        let minLon = coordinates.map(\.longitude).min() ?? first.longitude
        let maxLon = coordinates.map(\.longitude).max() ?? first.longitude
        let latitudeSpan = max((maxLat - minLat) * 2.4, 0.30)
        let longitudeSpan = max((maxLon - minLon) * 2.0, 0.18)
        let region = MKCoordinateRegion(
            center: .init(
                latitude: (minLat + maxLat) / 2 + latitudeSpan * 0.20,
                longitude: (minLon + maxLon) / 2
            ),
            span: .init(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
        )
        position = .region(region)
    }

    var filteredBeaches: [Beach] {
        guard !searchText.isEmpty else { return beaches }
        return beaches.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.displayName.localizedCaseInsensitiveContains(searchText)
            || $0.city.localizedCaseInsensitiveContains(searchText)
            || $0.displayCity.localizedCaseInsensitiveContains(searchText)
        }
    }

    func risk(for beach: Beach) -> RiskLevel {
        guard let impact = supportedImpactProbability(for: beach) else { return beach.baseRisk }
        if impact >= 0.55 { return .later }
        if impact >= 0.18 { return max(beach.baseRisk, .caution) }
        return beach.baseRisk
    }

    func impactProbability(for beach: Beach) -> Double {
        supportedImpactProbability(for: beach) ?? 0
    }

    private func supportedImpactProbability(for beach: Beach) -> Double? {
        guard forecastHour >= 0, !tracks.isEmpty else { return nil }
        let influenceRadius = 5_000.0
        var noImpactProbability = 1.0
        var contributingTrackCount = 0
        for track in tracks {
            guard let trackProbability = track.entryFraction(
                near: beach.coordinate,
                radius: influenceRadius,
                upTo: forecastHour
            ) else { continue }
            contributingTrackCount += 1
            noImpactProbability *= 1 - trackProbability
        }
        guard contributingTrackCount > 0 else { return nil }
        return min(max(1 - noImpactProbability, 0), 1)
    }

    func markedImpact(for beach: Beach) -> String {
        guard let probability = supportedImpactProbability(for: beach) else { return "Check later" }
        let value = "\(Int((probability * 100).rounded()))%"
        switch predictionQuality {
        case .mock: return value
        case .missing: return "Check later"
        case .stale: return "\(value) · RECENT"
        case .officialRegional: return "\(value) · REGIONAL"
        case .derived, .officialExact: return value
        }
    }

    func markedRisk(for beach: Beach) -> String {
        risk(for: beach).shortTitle
    }

    func recommendationScore(for beach: Beach, from origin: CLLocationCoordinate2D) -> Double {
        let riskPenalty = Double(risk(for: beach).rawValue) * 100
        let sightingPenalty = Double(beach.recentSightingsCount) * 14
        let currentPenalty = beach.marine.currentSpeed * 18
        // Unknown model coverage must not rank as a confirmed zero-impact beach.
        let modeledImpactPenalty = supportedImpactProbability(for: beach).map { $0 * 160 } ?? 80
        let distancePenalty = min(distance(from: origin, to: beach.coordinate), 80) * 0.25
        return riskPenalty + sightingPenalty + currentPenalty + modeledImpactPenalty + distancePenalty
    }

    func recommendationUsesMockData(for beach: Beach) -> Bool {
        predictionQuality == .mock
            || quality(for: beach, fields: .baseRisk, .jellyfishSightings, .current, .location) == .mock
    }

    func bestNearby(to coordinate: CLLocationCoordinate2D) -> Beach? {
        nearby(to: coordinate).min {
            recommendationScore(for: $0, from: coordinate) < recommendationScore(for: $1, from: coordinate)
        }
    }

    func recommendationReason(for beach: Beach, from origin: CLLocationCoordinate2D) -> String {
        guard let probability = supportedImpactProbability(for: beach) else {
            return "Recommended from available beach conditions."
        }
        let impactPercent = Int((probability * 100).rounded())
        if risk(for: beach) == .good && !beach.recentJellyfish {
            return "Lowest modeled jellyfish impact nearby (\(impactPercent)% at selected time)."
        }
        if beach.marine.currentSpeed < 0.4 {
            return "Calmer current and lower projected coastal inflow."
        }
        return "Best overall balance of risk, current, and distance."
    }

    var updatedText: String {
        let minutes = max(Int(Date().timeIntervalSince(lastUpdated) / 60), 0)
        return minutes == 0 ? "Updated just now" : "Updated \(minutes) min ago"
    }

    private static let provenanceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}
