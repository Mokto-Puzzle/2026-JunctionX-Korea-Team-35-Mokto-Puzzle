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
                RecommendationBanner(beach: recommendedBeach)
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("해수욕장 이름 검색", text: $searchText)
                        if !searchText.isEmpty { Button("지우기", systemImage: "xmark.circle.fill") { searchText = "" }.labelStyle(.iconOnly).foregroundStyle(.secondary) }
                    }
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    Button { showsFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill").font(.title2).frame(width: 44, height: 44)
                    }.buttonStyle(.glassProminent)
                }
                if !searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(searchResults.prefix(5)) { beach in
                            Button { focusedBeach = beach; selectedBeach = beach; searchText = "" } label: {
                                BeachRow(beach: beach).padding(.horizontal, 12).padding(.vertical, 5)
                            }.buttonStyle(.plain)
                            Divider().padding(.leading, 56)
                        }
                    }.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                if activeLayers.contains(.forecast) {
                    HStack {
                        Text("-24h").font(.caption)
                        Slider(value: $forecastHour, in: -24...12, step: 3)
                        Text(timeLabel).font(.caption.bold()).frame(width: 44)
                    }
                        .padding(.horizontal, 12).frame(height: 38).background(.regularMaterial, in: Capsule())
                }
            }.padding(.horizontal, 12)

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Button { focusedBeach = nil; searchText = "" } label: { Label("내 주변", systemImage: "location.fill") }.buttonStyle(.glass)
                    Spacer()
                    NavigationLink { BeachComparisonView(beaches: nearbyBeaches) } label: {
                        Image(systemName: "rectangle.split.3x1.fill").font(.title3).frame(width: 46, height: 46)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel("가까운 바다 비교")
                }.padding(14)
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
        forecastHour == 0 ? "현재" : forecastHour > 0 ? "+\(Int(forecastHour))h" : "\(Int(forecastHour))h"
    }
}

private struct RecommendationBanner: View {
    let beach: Beach
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("오늘의 추천", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.blue)
                Spacer()
                Text("18분 전 갱신").font(.caption2).foregroundStyle(.secondary)
            }
            Text("오늘은 \(beach.name)이\n가장 안심돼요")
                .font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            Text(beach.summary)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.top, 6)
    }
}

private struct BeachListSheet: View {
    @Binding var selectedBeach: Beach?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(Beach.samples) { beach in
                Button { selectedBeach = beach; dismiss() } label: { BeachRow(beach: beach) }.buttonStyle(.plain)
            }.navigationTitle("지금 갈 수 있는 바다")
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
                    Text("지도에 중첩할 정보")
                } footer: {
                    Text("예상 이동 경로가 기본으로 표시됩니다. 여러 항목을 동시에 켜서 관계를 확인할 수 있어요.")
                }
            }
            .navigationTitle("바다 정보 필터")
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
                        Text("해수욕장 비교").font(.headline)
                        Text("24곳 중 2~4곳 선택 · 현재 \(selection.count)곳").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("지도에서 보기") {
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
                .searchable(text: $searchText, prompt: "해수욕장 이름 또는 지역")
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
                Button("닫기", systemImage: "xmark.circle.fill") { dismiss() }.labelStyle(.iconOnly).font(.title2).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                infoCard("출몰 기록", "최근 \(beach.sightings)건", beach.sightings == 0 ? "최근 관측 없음" : "주의 필요", "binoculars.fill", beach.sightings == 0 ? .mint : .orange)
                infoCard("서핑", surfStatus, String(format: "파고 %.1fm", beach.wave), "figure.surfing", surfColor)
            }
            HStack(spacing: 8) {
                infoCard("해류", String(format: "%.1fm/s", beach.current), beach.current < 0.5 ? "비교적 잔잔" : "흐름 확인", "location.north.fill", .blue)
                infoCard("수온", String(format: "%.1f°C", beach.temperature), "\(beach.updatedMinutes)분 전", "thermometer.medium", temperatureColor)
            }
            Text(beach.summary).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var surfStatus: String { beach.wave >= 0.7 && beach.wave <= 1.6 && beach.safety != .danger ? "괜찮아요" : "확인 필요" }
    private var surfColor: Color { surfStatus == "괜찮아요" ? .cyan : .orange }
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
                Text("현재 조건과 거리를 함께 보면\n\(recommendation?.name ?? "가까운 바다")이 가장 적합해요.").font(.title2.bold())
                Text("내 위치에서 가까운 바다 \(beaches.count)곳").font(.headline)
                ForEach(beaches) { beach in
                    HStack(spacing: 14) {
                        Image(systemName: beach.safety.symbol).foregroundStyle(.white).frame(width: 42, height: 42).background(beach.safety.color, in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(beach.name).font(.headline)
                            Text("출몰 \(beach.sightings)건 · 해류 \(String(format: "%.1fm/s", beach.current)) · 수온 \(String(format: "%.1f°C", beach.temperature))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) { Text(beach.safety.rawValue).bold().foregroundStyle(beach.safety.color); Text("\(beach.distance)km").font(.caption) }
                    }
                    .padding(14).background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding()
        }.navigationTitle("가까운 바다 비교").navigationBarTitleDisplayMode(.inline)
    }
}

private struct JellyfishReportView: View {
    @State private var count = 1.0
    @State private var note = ""
    @State private var submitted = false
    var body: some View {
        Form {
            Section { ContentUnavailableView("사진을 추가해 주세요", systemImage: "camera.viewfinder", description: Text("해파리 종류와 제보 신뢰도를 확인하는 데 도움이 돼요.")); Button("사진 선택", systemImage: "photo.on.rectangle") {} }
            Section("발견 정보") { LabeledContent("위치", value: "현재 위치 근처"); DatePicker("발견 시각", selection: .constant(.now)); Stepper("발견 수 \(Int(count))마리", value: $count, in: 1...100); TextField("크기, 색상, 주변 상황", text: $note, axis: .vertical) }
            Section { Button("제보 보내기", systemImage: "paperplane.fill") { submitted = true }.frame(maxWidth: .infinity).buttonStyle(.borderedProminent) } footer: { Text("사용자 제보는 공식 관측과 구분해서 표시됩니다.") }
        }.navigationTitle("해파리 제보").alert("제보가 임시 저장됐어요", isPresented: $submitted) { Button("확인") {} } message: { Text("프로토타입이라 서버에는 전송되지 않습니다.") }
    }
}

private struct FavoritesView: View {
    @Binding var favorites: Set<Beach.ID>
    @State private var notifications = true
    var body: some View {
        List {
            Section("관심 바다") {
                ForEach(Beach.samples.filter { favorites.contains($0.id) }) { beach in BeachRow(beach: beach) }
                if favorites.isEmpty { ContentUnavailableView("관심 바다가 없어요", systemImage: "heart", description: Text("지도에서 자주 가는 바다를 저장해 보세요.")) }
            }
            Section("알림") { Toggle("위험 단계가 바뀌면 알림", isOn: $notifications); Toggle("신규 해파리 관측", isOn: $notifications); Toggle("공식 입수 통제", isOn: $notifications) }
            Section("안전 가이드") { Label("해파리를 발견했을 때", systemImage: "eye.trianglebadge.exclamationmark"); Label("해파리에 쏘였을 때", systemImage: "cross.case.fill"); Label("공식 특보와 현장 안내", systemImage: "megaphone.fill") }
        }.navigationTitle("관심과 안전")
    }
}

#Preview { JellyfishPrototypeView() }
