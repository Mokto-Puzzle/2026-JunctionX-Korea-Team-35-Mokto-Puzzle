import MapKit
import SwiftUI

struct JellyfishPrototypeView: View {
    var body: some View {
        NavigationStack { HomeMapView() }
            .tint(.blue)
    }
}

private struct HomeMapView: View {
    @State private var selectedBeach: Beach?
    @State private var activeLayers: Set<OceanDisplayLayer> = [.forecast]
    @State private var forecastHour = 0.0
    @State private var showsFilters = false
    @State private var searchText = ""
    @State private var focusedBeach: Beach?

    private var nearbyBeaches: [Beach] {
        Array(Beach.samples.sorted { $0.distance < $1.distance }.prefix(4))
    }

    private var recommendedBeach: Beach {
        nearbyBeaches.sorted {
            if $0.safety.rank != $1.safety.rank { return $0.safety.rank < $1.safety.rank }
            if $0.sightings != $1.sightings { return $0.sightings < $1.sightings }
            return $0.distance < $1.distance
        }.first!
    }

    private var displayedBeaches: [Beach] {
        if let focusedBeach { return [focusedBeach] }
        return nearbyBeaches
    }

    private var searchResults: [Beach] {
        searchText.isEmpty ? [] : Beach.samples.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.region.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            OceanVisualizationView(layers: activeLayers, forecastHour: forecastHour, beaches: displayedBeaches) { selectedBeach = $0 }
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 9) {
                RecommendationBanner(beach: recommendedBeach) { showsFilters = true }
                if activeLayers.contains(.forecast) {
                    HStack {
                        Text("Past").font(.caption.bold()).foregroundStyle(.secondary)
                        Slider(value: $forecastHour, in: -24...12, step: 3)
                            .tint(Color.brandTeal)
                        Text("Future").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                        .padding(.horizontal, 14).frame(height: 42).background(.regularMaterial, in: Capsule())
                    Text(timeLabel).font(.caption2.bold()).foregroundStyle(Color.brandTeal)
                }
            }.padding(.horizontal, 12)

            VStack {
                Spacer()
                if !searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(searchResults.prefix(4)) { beach in
                            Button { focusedBeach = beach; selectedBeach = beach; searchText = "" } label: {
                                BeachRow(beach: beach).padding(.horizontal, 12).padding(.vertical, 5)
                            }.buttonStyle(.plain)
                            if beach.id != searchResults.prefix(4).last?.id { Divider().padding(.leading, 54) }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 12)
                }
                HStack {
                    Button { focusedBeach = nil; searchText = "" } label: {
                        Image(systemName: "location.circle.fill").font(.title2).foregroundStyle(Color.brandTeal)
                    }.buttonStyle(.glass)
                    Spacer()
                    NavigationLink { BeachComparisonView(beaches: nearbyBeaches) } label: {
                        Label("Compare", systemImage: "plus.circle").font(.subheadline.bold())
                    }.buttonStyle(.glassProminent).tint(Color.brandTeal)
                }.padding(.horizontal, 16).padding(.bottom, 8)
                VStack(spacing: 12) {
                    Capsule().fill(.secondary.opacity(0.35)).frame(width: 38, height: 5)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search", text: $searchText)
                        if !searchText.isEmpty { Button("Clear", systemImage: "xmark.circle.fill") { searchText = "" }.labelStyle(.iconOnly).foregroundStyle(.secondary) }
                        Image(systemName: "mic.fill").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(Color(.secondarySystemBackground).opacity(0.82), in: Capsule())
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
                .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            }
        }
        .sheet(item: $selectedBeach) { beach in
            BeachDetailSheet(beach: beach)
                .presentationDetents([.height(310), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(310)))
        }
        .sheet(isPresented: $showsFilters) {
            LayerFilterSheet(selection: $activeLayers).presentationDetents([.height(355)]).presentationDragIndicator(.visible)
        }
    }

    private var timeLabel: String {
        forecastHour == 0 ? "Now" : forecastHour > 0 ? "+\(Int(forecastHour))h" : "\(Int(forecastHour))h"
    }
}

private struct RecommendationBanner: View {
    let beach: Beach
    let filterAction: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                JellyfishGlyph().fill(Color.brandTeal).frame(width: 34, height: 34)
                Spacer()
            }
            Text(Date.now.formatted(.dateTime.month(.wide).day().year()))
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .bottom) {
                (Text(beach.name).foregroundStyle(Color.brandTeal) + Text(" is your\nsafest choice today!").foregroundStyle(Color(red: 0.02, green: 0.20, blue: 0.20)))
                    .font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: filterAction) { Image(systemName: "line.3.horizontal.decrease") }
                    .buttonStyle(.glass).tint(Color.brandTeal).accessibilityLabel("Ocean layers")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    }
}

private struct BeachListSheet: View {
    @Binding var selectedBeach: Beach?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(Beach.samples) { beach in
                Button { selectedBeach = beach; dismiss() } label: { BeachRow(beach: beach) }.buttonStyle(.plain)
            }.navigationTitle("Beaches Available Now")
        }
    }
}

private struct LayerFilterSheet: View {
    @Binding var selection: Set<OceanDisplayLayer>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(OceanDisplayLayer.allCases) { layer in
                        Toggle(isOn: Binding(
                            get: { selection.contains(layer) },
                            set: { enabled in
                                if enabled { selection.insert(layer) } else { selection.remove(layer) }
                            }
                        )) {
                            Label(layer.rawValue, systemImage: symbol(for: layer))
                        }
                    }
                } header: {
                    Text("MAP OVERLAYS")
                } footer: {
                    Text("The predicted route is shown by default. Turn on multiple layers to explore how they relate.")
                }
            }
            .navigationTitle("Ocean Layers")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func symbol(for layer: OceanDisplayLayer) -> String {
        switch layer {
        case .forecast: "point.topleft.down.to.point.bottomright.curvepath"
        case .current: "water.waves.and.arrow.trianglehead.counterclockwise"
        case .temperature: "thermometer.variable"
        }
    }
}

private struct CompareSelectionSheet: View {
    @Binding var selection: Set<Beach.ID>
    let apply: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredBeaches: [Beach] {
        searchText.isEmpty ? Beach.samples : Beach.samples.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Compare Beaches").font(.headline)
                        Text("Select 2–4 of 24 · \(selection.count) selected").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("View on Map") {
                        apply()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection.count < 2)
                }
                .padding(.horizontal)

                List(filteredBeaches) { beach in
                    Button { toggle(beach.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selection.contains(beach.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(selection.contains(beach.id) ? .blue : .secondary)
                            BeachRow(beach: beach)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!selection.contains(beach.id) && selection.count >= 4)
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Beach name or region")
            }
            .padding(.top, 8)
        }
    }

    private func toggle(_ id: Beach.ID) {
        if selection.contains(id) { selection.remove(id) }
        else if selection.count < 4 { selection.insert(id) }
    }
}

private struct BeachRow: View {
    let beach: Beach
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: beach.safety.symbol).foregroundStyle(.white).frame(width: 36, height: 36).background(beach.safety.color, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(beach.name).font(.headline)
                Text("\(beach.region) · \(beach.distance)km · \(beach.bestTime)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(); Text(beach.safety.rawValue).font(.subheadline.bold()).foregroundStyle(beach.safety.color)
        }.padding(.vertical, 4)
    }
}

private struct BeachDetailSheet: View {
    let beach: Beach
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(beach.name).font(.title2.bold())
                    Label(beach.safety.rawValue, systemImage: beach.safety.symbol).font(.subheadline.bold()).foregroundStyle(beach.safety.color)
                }
                Spacer()
                Button("Close", systemImage: "xmark.circle.fill") { dismiss() }.labelStyle(.iconOnly).font(.title2).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                infoCard("Sightings", "\(beach.sightings) recent", beach.sightings == 0 ? "None reported" : "Use caution", "binoculars.fill", beach.sightings == 0 ? .mint : .orange)
                infoCard("Surfing", surfStatus, String(format: "Waves %.1fm", beach.wave), "figure.surfing", surfColor)
            }
            HStack(spacing: 8) {
                infoCard("Current", String(format: "%.1fm/s", beach.current), beach.current < 0.5 ? "Relatively calm" : "Check direction", "location.north.fill", .blue)
                infoCard("Water Temp", String(format: "%.1f°C", beach.temperature), "\(beach.updatedMinutes) min ago", "thermometer.medium", temperatureColor)
            }
            Text(beach.summary).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var surfStatus: String { beach.wave >= 0.7 && beach.wave <= 1.6 && beach.safety != .danger ? "Good" : "Check first" }
    private var surfColor: Color { surfStatus == "Good" ? .cyan : .orange }
    private var temperatureColor: Color { beach.temperature >= 27 ? .red : beach.temperature >= 26 ? .orange : .blue }

    private func infoCard(_ title: String, _ value: String, _ note: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.caption.bold()).foregroundStyle(color)
            Text(value).font(.headline)
            Text(note).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct BeachComparisonView: View {
    let beaches: [Beach]
    private var recommendation: Beach? {
        beaches.sorted {
            if $0.safety.rank != $1.safety.rank { return $0.safety.rank < $1.safety.rank }
            return $0.distance < $1.distance
        }.first
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Based on current conditions and distance,\n\(recommendation?.name ?? "a nearby beach") is the best choice.").font(.title2.bold())
                Text("\(beaches.count) beaches near you").font(.headline)
                ForEach(beaches) { beach in
                    HStack(spacing: 14) {
                        Image(systemName: beach.safety.symbol).foregroundStyle(.white).frame(width: 42, height: 42).background(beach.safety.color, in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(beach.name).font(.headline)
                            Text("\(beach.sightings) sightings · Current \(String(format: "%.1fm/s", beach.current)) · Water \(String(format: "%.1f°C", beach.temperature))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) { Text(beach.safety.rawValue).bold().foregroundStyle(beach.safety.color); Text("\(beach.distance)km").font(.caption) }
                    }
                    .padding(14).background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding()
        }.navigationTitle("Compare Nearby Beaches").navigationBarTitleDisplayMode(.inline)
    }
}

private struct JellyfishReportView: View {
    @State private var count = 1.0
    @State private var note = ""
    @State private var submitted = false
    var body: some View {
        Form {
            Section { ContentUnavailableView("Add a Photo", systemImage: "camera.viewfinder", description: Text("A photo helps identify the species and verify the report.")); Button("Choose Photo", systemImage: "photo.on.rectangle") {} }
            Section("Sighting Details") { LabeledContent("Location", value: "Near current location"); DatePicker("Time spotted", selection: .constant(.now)); Stepper("Count: \(Int(count))", value: $count, in: 1...100); TextField("Size, color, and surroundings", text: $note, axis: .vertical) }
            Section { Button("Submit Report", systemImage: "paperplane.fill") { submitted = true }.frame(maxWidth: .infinity).buttonStyle(.borderedProminent) } footer: { Text("Community reports are shown separately from official observations.") }
        }.navigationTitle("Report a Jellyfish").alert("Report saved temporarily", isPresented: $submitted) { Button("OK") {} } message: { Text("This prototype does not send data to a server.") }
    }
}

private struct FavoritesView: View {
    @Binding var favorites: Set<Beach.ID>
    @State private var notifications = true
    var body: some View {
        List {
            Section("Saved Beaches") {
                ForEach(Beach.samples.filter { favorites.contains($0.id) }) { beach in BeachRow(beach: beach) }
                if favorites.isEmpty { ContentUnavailableView("No Saved Beaches", systemImage: "heart", description: Text("Save your favorite beaches from the map.")) }
            }
            Section("Notifications") { Toggle("Risk level changes", isOn: $notifications); Toggle("New jellyfish sightings", isOn: $notifications); Toggle("Official swimming restrictions", isOn: $notifications) }
            Section("Safety Guide") { Label("When you spot a jellyfish", systemImage: "eye.trianglebadge.exclamationmark"); Label("If you are stung", systemImage: "cross.case.fill"); Label("Official alerts and on-site guidance", systemImage: "megaphone.fill") }
        }.navigationTitle("Saved & Safety")
    }
}

#Preview { JellyfishPrototypeView() }
