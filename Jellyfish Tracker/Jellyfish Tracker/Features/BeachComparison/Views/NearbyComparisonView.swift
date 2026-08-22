import SwiftUI
import CoreLocation

struct NearbyComparisonView: View {
    @ObservedObject var model: JellyMapViewModel
    let userCoordinate: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss

    private var nearby: [Beach] { model.nearby(to: userCoordinate) }
    private var best: Beach? { model.bestNearby(to: userCoordinate) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.trackerNavy.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        recommendation
                        HStack {
                            Text("AUTO: NEAREST \(nearby.count)").font(.caption.monospaced().bold()).foregroundStyle(Color.trackerCyan)
                            Spacer()
                            Text(model.updatedText).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        ForEach(nearby) { beach in comparisonCard(beach) }
                        Text("! = mock/fallback only · REGION ESTIMATE = official NIFS area, not an exact coordinate · OUTDATED/NO DATA are shown separately. Not an official safety advisory.")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 6)
                    }
                    .padding()
                }
            }
            .navigationTitle("Nearby Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var recommendation: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill").font(.title2).foregroundStyle(Color.seafoam)
            VStack(alignment: .leading, spacing: 4) {
                Text(best.map {
                    model.recommendationUsesMockData(for: $0)
                        ? "Demo comparison: \($0.displayName)"
                        : "Lowest modeled impact: \($0.displayName)"
                } ?? "Comparing nearby beaches…")
                    .font(.headline)
                if let best {
                    Text(model.recommendationReason(for: best, from: userCoordinate))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14).trackerPanel(cornerRadius: 12)
    }

    private func comparisonCard(_ beach: Beach) -> some View {
        let risk = model.risk(for: beach)
        let isBest = best?.id == beach.id
        return VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(beach.displayName).font(.headline)
                        if isBest {
                            Text("BEST PICK").font(.caption2.monospaced().bold()).foregroundStyle(Color.trackerNavy)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .background(Color.trackerCream, in: .rect(cornerRadius: 3))
                        }
                    }
                    Text("\(beach.displayCity) · \(model.annotated(String(format: "%.1f km", model.distance(from: userCoordinate, to: beach.coordinate)), for: beach, fields: .location))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.markedRisk(for: beach).uppercased()).font(.caption.monospaced().bold()).foregroundStyle(Color.trackerNavy)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Color.risk(risk), in: .rect(cornerRadius: 4))
            }
            Divider().overlay(Color.trackerCyan.opacity(0.35))
            HStack(spacing: 0) {
                comparisonMetric("IMPACT", model.markedImpact(for: beach))
                comparisonMetric("SIGHTINGS", model.annotated(beach.recentJellyfish ? "\(beach.recentSightingsCount) recent" : "None", for: beach, fields: .jellyfishSightings))
                comparisonMetric("CURRENT", model.annotated(String(format: "%.2f m/s", beach.marine.currentSpeed), for: beach, fields: .current))
                comparisonMetric("SURF", model.annotated(beach.surfStatus, for: beach, fields: .waveHeight, .baseRisk))
            }
            HStack {
                Text("Recommended: \(model.annotated(beach.recommendedVisitTime, for: beach, fields: .baseRisk))").font(.caption.bold())
                Spacer()
                Text(model.updatedText).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14).trackerPanel(cornerRadius: 12)
    }

    private func comparisonMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2.monospaced().bold()).foregroundStyle(Color.trackerCyan)
            Text(value).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }
}
