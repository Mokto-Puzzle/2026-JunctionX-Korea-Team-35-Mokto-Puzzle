import SwiftUI

struct BeachDetailPanel: View {
    let beach: Beach
    let risk: RiskLevel
    let impactProbability: Double
    let updatedText: String
    let sourceLabel: String
    let predictionUsesMockData: Bool
    let predictionStatus: String?
    let provenance: [BeachDataField: String]
    let dataQualities: [BeachDataField: DataQuality]
    @Binding var expanded: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(AppColor.LegacyTracker.cream.opacity(0.55))
                .frame(width: 42, height: 5).padding(.top, 9).padding(.bottom, 8)
            header
            if expanded {
                ScrollView { expandedContent.padding(.bottom, 28) }
                    .transition(.opacity)
            } else {
                quickSummary
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: expanded ? 590 : 186, alignment: .top)
        .background(AppColor.LegacyTracker.panel.opacity(0.98), in: .rect(topLeadingRadius: 18, topTrailingRadius: 18))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                .stroke(AppColor.LegacyTracker.cyan, lineWidth: 2)
        }
        .shadow(color: AppColor.Shadow.topStrong, radius: 18, y: -4)
        .gesture(
            DragGesture(minimumDistance: 18).onEnded { value in
                withAnimation(.snappy) {
                    if value.translation.height < -40 { expanded = true }
                    if value.translation.height > 40 { expanded = false }
                }
            }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(beach.displayName).font(.title3.bold()).fontDesign(.rounded)
                Text("\(beach.displayCity) · Gyeongsangbuk-do")
                    .font(.caption.monospaced()).foregroundStyle(AppColor.Text.secondary)
            }
            Spacer()
            Text((risk.shortTitle + (predictionUsesMockData || beach.usesMock(.baseRisk) ? "!" : "")).uppercased())
                .font(.caption.monospaced().bold()).foregroundStyle(AppColor.LegacyTracker.navy)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(AppColor.risk(risk), in: .rect(cornerRadius: 5))
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.up")
            }
            .buttonStyle(.bordered).accessibilityLabel(expanded ? "Collapse details" : "Expand details")
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(.bordered).accessibilityLabel("Close beach details")
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private var quickSummary: some View {
        HStack(spacing: 0) {
            quickMetric("JELLYFISH", value: annotated(beach.recentJellyfish ? "\(beach.recentSightingsCount) recent" : "None", fields: .jellyfishSightings), icon: "dot.radiowaves.left.and.right")
            Divider().frame(height: 42)
            quickMetric("SURF", value: annotated(beach.surfStatus, fields: .waveHeight, .baseRisk), icon: "figure.surfing")
            Divider().frame(height: 42)
            quickMetric("CURRENT", value: annotated(String(format: "%.2f m/s", beach.marine.currentSpeed), fields: .current), icon: "arrow.up.right")
            Divider().frame(height: 42)
            quickMetric("WATER", value: annotated(String(format: "%.1f°C", beach.marine.waterTemperature), fields: .waterTemperature), icon: "thermometer.medium")
        }
        .padding(.horizontal, 8)
    }

    private func quickMetric(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(AppColor.LegacyTracker.cyan)
            Text(title).font(.caption2.monospaced().bold()).foregroundStyle(AppColor.Text.secondary)
            Text(value).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusSummary
            detailSection("JELLYFISH SIGHTINGS", icon: "dot.radiowaves.left.and.right") {
                metricRow("Particle entry impact", "\(Int((impactProbability * 100).rounded()))%\(predictionUsesMockData ? "!" : "")")
                if let predictionStatus { metricRow("Prediction quality", predictionStatus) }
                metricRow("Recent reports", annotated(beach.recentJellyfish ? "\(beach.recentSightingsCount)" : "0", fields: .jellyfishSightings))
                metricRow("Last observation", annotated(beach.sightingSummary, fields: .jellyfishSightings))
                metricRow("Species", annotated(beach.displaySpecies, fields: .species))
                metricRow("Source", sourceLabel)
            }
            detailSection("ACTIVITY CONDITIONS", icon: "figure.surfing") {
                metricRow("Surfing", annotated(beach.surfStatus, fields: .waveHeight, .baseRisk))
                metricRow("Wave height", annotated(String(format: "%.1f m", beach.marine.waveHeight), fields: .waveHeight))
                ForEach(ActivityGroup.allCases) { activity in
                    metricRow(activity.rawValue, annotated(beach.activities[activity]?.shortTitle ?? "Check", fields: .activities))
                }
            }
            detailSection("OCEAN CONDITIONS", icon: "water.waves") {
                metricRow("Current", annotated(String(format: "%.2f m/s · %.0f°", beach.marine.currentSpeed, beach.marine.currentDirection), fields: .current))
                metricRow("Current context", annotated(beach.currentDescription, fields: .current))
                metricRow("Water temperature", annotated(String(format: "%.1f°C", beach.marine.waterTemperature), fields: .waterTemperature))
                metricRow("Wind", annotated(String(format: "%.1f m/s", beach.marine.windSpeed), fields: .wind))
                metricRow("Freshness", updatedText)
            }
            detailSection("DATA SOURCES", icon: "checkmark.seal") {
                provenanceRow("Jellyfish", field: .jellyfishSightings)
                provenanceRow("Current", field: .current)
                provenanceRow("Wave", field: .waveHeight)
                provenanceRow("Water temperature", field: .waterTemperature)
                provenanceRow("Location", field: .location)
                Text("! is used only for mock or fallback values. Regional estimates, outdated values, and missing values have separate labels.")
                    .font(.caption2).foregroundStyle(AppColor.Text.secondary)
            }
            if !beach.displayFacilities.isEmpty {
                detailSection("FACILITIES", icon: "info.circle") {
                    Text(beach.displayFacilities.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(AppColor.Text.secondary)
                }
            }
            Text("This prototype is for trip planning only. Official marine warnings, beach closures, and on-site lifeguard instructions always take priority.")
                .font(.caption).foregroundStyle(AppColor.Text.secondary)
                .padding(12)
                .background(AppColor.LegacyTracker.navy.opacity(0.45), in: .rect(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
    }

    private var statusSummary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: risk == .good ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.title2).foregroundStyle(AppColor.risk(risk))
            VStack(alignment: .leading, spacing: 3) {
                Text(risk == .good ? "Good conditions for a beach visit" : "Review conditions before visiting")
                    .font(.headline)
                Text(beach.recentJellyfish
                    ? "Recent sightings and the forecast route increase uncertainty near this beach."
                     : "No recent sightings are reported and projected impact is currently low.")
                    .font(.subheadline).foregroundStyle(AppColor.Text.secondary)
            }
        }
        .padding(12)
        .background(AppColor.risk(risk).opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private func detailSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.monospaced().bold()).foregroundStyle(AppColor.LegacyTracker.cyan)
            content()
        }
        .padding(12)
        .background(AppColor.LegacyTracker.navy.opacity(0.38), in: .rect(cornerRadius: 8))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(AppColor.Text.secondary)
            Spacer(minLength: 12)
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func provenanceRow(_ label: String, field: BeachDataField) -> some View {
        metricRow(label, provenance[field] ?? "[NO DATA] Unknown source")
    }

    private func annotated(_ value: String, fields: BeachDataField...) -> String {
        let qualities = fields.compactMap { dataQualities[$0] }
        if qualities.contains(.mock) { return "\(value)!" }
        if qualities.contains(.missing) { return "No data" }
        if qualities.contains(.stale) { return "\(value) · OUTDATED" }
        if qualities.contains(.officialRegional) { return "\(value) · REGION EST." }
        return value
    }
}
