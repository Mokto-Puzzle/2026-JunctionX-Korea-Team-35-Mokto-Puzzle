import MapKit
import SwiftUI

struct JellyfishPrototypeView: View {
    @State private var selectedTab = 0
    @State private var compareSelection = Set(Beach.samples.prefix(2).map(\.id))
    @State private var favorites = Set([Beach.samples[0].id])

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeMapView(favorites: $favorites, compareSelection: $compareSelection)
            }
            .tabItem { Label("지도", systemImage: "map.fill") }
            .tag(0)

            NavigationStack {
                BeachComparisonView(selection: $compareSelection)
            }
            .tabItem { Label("비교", systemImage: "rectangle.split.3x1") }
            .tag(1)

            NavigationStack { JellyfishReportView() }
                .tabItem { Label("제보", systemImage: "camera.fill") }
                .tag(2)

            NavigationStack {
                FavoritesView(favorites: $favorites)
            }
            .tabItem { Label("관심", systemImage: "heart.fill") }
            .tag(3)
        }
        .tint(.blue)
    }
}

private struct HomeMapView: View {
    @Binding var favorites: Set<Beach.ID>
    @Binding var compareSelection: Set<Beach.ID>
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 36.42, longitude: 129.39), span: .init(latitudeDelta: 1.35, longitudeDelta: 0.75)))
    @State private var selectedBeach: Beach?
    @State private var layer: HomeLayer = .risk
    @State private var forecastHour = 0.0
    @State private var showsList = false

    enum HomeLayer: String, CaseIterable, Identifiable {
        case risk = "위험도"
        case forecast = "예상 이동"
        case current = "해류"
        case temperature = "수온"
        var id: Self { self }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                if layer == .forecast {
                    MapPolyline(coordinates: forecastPath)
                        .stroke(.purple, style: .init(lineWidth: 5, lineCap: .round, dash: [8, 7]))
                    MapCircle(center: forecastCoordinate, radius: 7_000 + forecastHour * 600)
                        .foregroundStyle(.purple.opacity(0.16))
                        .stroke(.purple.opacity(0.7), style: .init(lineWidth: 2, dash: [6, 5]))
                }
                if layer == .current {
                    ForEach(Array(Beach.samples.enumerated()), id: \.element.id) { index, beach in
                        Annotation("", coordinate: shifted(beach.coordinate, by: 0.08)) {
                            VStack(spacing: 2) {
                                Image(systemName: "location.north.fill")
                                    .font(.title2.bold()).foregroundStyle(.blue)
                                    .rotationEffect(.degrees(Double(index * 18 - 20)))
                                Text(String(format: "%.1fm/s", beach.current)).font(.caption2.bold())
                            }
                        }
                    }
                }
                if layer == .temperature {
                    ForEach(Beach.samples) { beach in
                        MapCircle(center: shifted(beach.coordinate, by: 0.07), radius: 16_000)
                            .foregroundStyle(tempColor(beach.temperature).opacity(0.35))
                    }
                }
                ForEach(Beach.samples) { beach in
                    Annotation(beach.name, coordinate: beach.coordinate, anchor: .bottom) {
                        Button { selectedBeach = beach } label: {
                            VStack(spacing: 4) {
                                Image(systemName: beach.safety.symbol)
                                    .font(.headline.bold()).foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(beach.safety.color.gradient, in: Circle())
                                    .overlay(Circle().stroke(beach.id == Beach.samples[0].id ? .blue : .white, lineWidth: beach.id == Beach.samples[0].id ? 5 : 2))
                                    .shadow(radius: 4, y: 2)
                                if beach.id == Beach.samples[0].id {
                                    Text("추천").font(.caption2.bold()).foregroundStyle(.blue)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(.regularMaterial, in: Capsule())
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                RecommendationBanner()
                Picker("지도 레이어", selection: $layer) {
                    ForEach(HomeLayer.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(5).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                if layer == .forecast {
                    HStack {
                        Text("현재").font(.caption)
                        Slider(value: $forecastHour, in: 0...12, step: 3)
                        Text("+\(Int(forecastHour))h").font(.caption.bold()).frame(width: 38)
                    }
                    .padding(.horizontal, 12).frame(height: 42)
                    .background(.regularMaterial, in: Capsule())
                }
            }.padding(.horizontal, 12)

            VStack {
                Spacer()
                HStack {
                    NavigationLink { MapPlaygroundView() } label: {
                        Label("실험실", systemImage: "slider.horizontal.3")
                    }.buttonStyle(.glass)
                    Spacer()
                    Button { showsList = true } label: {
                        Label("바다 목록", systemImage: "list.bullet")
                    }.buttonStyle(.glassProminent)
                }.padding(14)
            }
        }
        .navigationDestination(item: $selectedBeach) { beach in
            BeachDetailView(beach: beach, isFavorite: favorites.contains(beach.id)) {
                if favorites.contains(beach.id) { favorites.remove(beach.id) } else { favorites.insert(beach.id) }
            } compare: {
                compareSelection.insert(beach.id)
            }
        }
        .sheet(isPresented: $showsList) {
            BeachListSheet(selectedBeach: $selectedBeach)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var forecastPath: [CLLocationCoordinate2D] { [.init(latitude: 36.22, longitude: 129.49), .init(latitude: 36.30, longitude: 129.46), forecastCoordinate] }
    private var forecastCoordinate: CLLocationCoordinate2D { .init(latitude: 36.30 + forecastHour * 0.014, longitude: 129.46 + forecastHour * 0.004) }
    private func shifted(_ coordinate: CLLocationCoordinate2D, by longitude: Double) -> CLLocationCoordinate2D { .init(latitude: coordinate.latitude, longitude: coordinate.longitude + longitude) }
    private func tempColor(_ value: Double) -> Color { value >= 27 ? .red : value >= 26 ? .orange : value >= 25 ? .yellow : .blue }
}

private struct RecommendationBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("오늘의 추천", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.blue)
                Spacer()
                Text("18분 전 갱신").font(.caption2).foregroundStyle(.secondary)
            }
            Text("오늘은 월포해수욕장이\n가장 안심돼요")
                .font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            Text("최근 관측이 적고 해류가 연안 반대 방향이에요.")
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

private struct BeachDetailView: View {
    let beach: Beach
    let isFavorite: Bool
    let favorite: () -> Void
    let compare: () -> Void
    private let timeline: [HourlySafety] = [
        .init(time: "현재", safety: .calm, reason: "최근 관측 적음"),
        .init(time: "15시", safety: .calm, reason: "해류 안정"),
        .init(time: "18시", safety: .caution, reason: "유입 가능성"),
        .init(time: "내일", safety: .unknown, reason: "예측 변동")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(beach.safety.rawValue, systemImage: beach.safety.symbol).font(.headline).foregroundStyle(beach.safety.color)
                    Text(beach.safety == .calm ? "지금은 비교적 안심하고\n방문할 수 있어요" : beach.summary).font(.largeTitle.bold())
                    Text("\(beach.updatedMinutes)분 전 갱신 · 디자인용 샘플 데이터").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    metric("수온", String(format: "%.1f°", beach.temperature), "thermometer.medium")
                    metric("파고", String(format: "%.1fm", beach.wave), "water.waves")
                    metric("해류", String(format: "%.1fm/s", beach.current), "location.north.fill")
                    metric("관측", "\(beach.sightings)건", "binoculars.fill")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("시간대별 전망").font(.title3.bold())
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(timeline) { item in
                            VStack(spacing: 7) {
                                Text(item.time).font(.caption.bold())
                                Image(systemName: item.safety.symbol).foregroundStyle(.white).frame(width: 32, height: 32).background(item.safety.color, in: Circle())
                                Text(item.reason).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity)
                        }
                    }.padding().background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("이렇게 판단했어요").font(.title3.bold())
                    Text(beach.summary).font(.body)
                    reason("최근 해파리 관측", beach.sightings == 0 ? "위험을 낮추는 요인" : "주의 요인", beach.sightings == 0 ? .mint : .orange)
                    reason("해류 방향", beach.current < 0.5 ? "연안 유입 가능성 낮음" : "변화 관찰 필요", beach.current < 0.5 ? .mint : .orange)
                    reason("데이터 신선도", beach.updatedMinutes < 60 ? "최근 정보" : "확인 필요", beach.updatedMinutes < 60 ? .blue : .gray)
                }
                DisclosureGroup("예측과 데이터의 한계") {
                    Text("이 정보는 해양 조건과 관측 자료를 조합한 상대적 판단이며, 공식 특보와 현장 안전요원의 안내를 대체하지 않습니다.").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                }
                HStack {
                    Button(action: favorite) { Label(isFavorite ? "저장됨" : "관심 등록", systemImage: isFavorite ? "heart.fill" : "heart") }.buttonStyle(.bordered)
                    Button(action: compare) { Label("비교 담기", systemImage: "plus.square.on.square") }.buttonStyle(.bordered)
                    Button("길찾기", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {}.buttonStyle(.borderedProminent)
                }
            }.padding()
        }.navigationTitle(beach.name).navigationBarTitleDisplayMode(.inline)
    }
    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View { VStack(spacing: 6) { Image(systemName: symbol).foregroundStyle(.blue); Text(value).font(.headline); Text(title).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) }
    private func reason(_ title: String, _ value: String, _ color: Color) -> some View { HStack { Circle().fill(color).frame(width: 8, height: 8); Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }.font(.subheadline).padding(.vertical, 4) }
}

private struct BeachComparisonView: View {
    @Binding var selection: Set<Beach.ID>
    private var beaches: [Beach] { Beach.samples.filter { selection.contains($0.id) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("현재 조건과 거리를 함께 보면\n월포해수욕장이 가장 적합해요.").font(.title2.bold())
                Text("비교할 바다 선택").font(.headline)
                ForEach(Beach.samples) { beach in
                    Toggle(isOn: Binding(get: { selection.contains(beach.id) }, set: { enabled in if enabled { selection.insert(beach.id) } else { selection.remove(beach.id) } })) { BeachRow(beach: beach) }
                }
                if !beaches.isEmpty {
                    Divider(); Text("선택한 바다").font(.headline)
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(beaches.prefix(3)) { beach in
                            VStack(spacing: 9) {
                                Image(systemName: beach.safety.symbol).foregroundStyle(.white).frame(width: 38, height: 38).background(beach.safety.color, in: Circle())
                                Text(beach.name.replacingOccurrences(of: "해수욕장", with: "")).font(.subheadline.bold())
                                Text(beach.safety.rawValue).foregroundStyle(beach.safety.color)
                                Divider(); Text("\(beach.distance)km"); Text(String(format: "파고 %.1fm", beach.wave)); Text("관측 \(beach.sightings)건")
                            }.font(.caption).frame(maxWidth: .infinity).padding(12).background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }.padding()
        }.navigationTitle("바다 비교")
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
