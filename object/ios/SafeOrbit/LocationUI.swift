import SwiftUI
import MapKit

enum CaregiverTab: String, CaseIterable {
    case location = "Location", agent = "Agent", records = "Records"
    var symbol: String {
        switch self {
        case .location: return "person.badge.location.fill"
        case .agent: return "sparkle"
        case .records: return "chart.bar.xaxis"
        }
    }
}

struct CaregiverTabBar: View {
    @Binding var selection: CaregiverTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CaregiverTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.black)
                        .background(selection == tab ? Color(red: 0.82, green: 0.90, blue: 0.90) : .clear, in: Capsule())
                }.accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(7).frame(maxWidth: 294)
        .background {
            Capsule().fill(.white)
                .shadow(color: .black.opacity(0.133), radius: 9, y: 4)
        }
    }
}

struct CaregiverHomePage: View {
    @ObservedObject var store: OnboardingStore
    @State private var tab: CaregiverTab = .location
    @State private var navigating = false
    var body: some View {
        ZStack {
            if tab == .location {
                LocationPage(profile: store.elder, snapshot: store.location,
                             message: store.locationError, loading: store.locationLoading,
                             refresh: { Task { await store.refreshLocation() } },
                             agent: { tab = .agent }, navigate: { navigating = true })
            } else {
                Color.white.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: tab.symbol).font(.system(size: 38)).foregroundStyle(OrbitStyle.teal)
                    Text(tab.rawValue).font(.system(size: 28, weight: .semibold))
                    Text("Coming soon").font(.subheadline).foregroundStyle(.secondary)
                    Button("Sign out") { Task { await store.signOut() } }
                        .font(.footnote).padding(.top, 18)
                }.offset(y: -30)
            }
            VStack { Spacer(); CaregiverTabBar(selection: $tab).padding(.bottom, 13) }
#if DEBUG
            if store.previewSession {
                VStack {
                    Button("Exit preview") { Task { await store.signOut() } }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OrbitStyle.teal)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white, in: Capsule())
                        .padding(.top, 10)
                    Spacer()
                }
            }
#endif
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.refreshLocation() }
        .fullScreenCover(isPresented: $navigating) {
            WalkingNavigationPage(snapshot: store.location, name: store.elder.name) { navigating = false }
        }
    }
}

struct LocationPage: View {
    let profile: ElderProfile
    let snapshot: ElderLocationSnapshot?
    let message: String?
    let loading: Bool
    let refresh: () -> Void
    let agent: () -> Void
    let navigate: () -> Void
    @State private var camera: MapCameraPosition = .automatic

    private var point: CLLocationCoordinate2D? { snapshot?.coordinate.isValid == true ? snapshot?.coordinate.appleCoordinate : nil }
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                if let snapshot {
                    ForEach(snapshot.safeZones.filter { $0.center.isValid && $0.radiusMeters > 0 }, id: \.id) { zone in
                        MapCircle(center: zone.center.appleCoordinate, radius: zone.radiusMeters)
                            .foregroundStyle(OrbitStyle.teal.opacity(0.10))
                            .stroke(OrbitStyle.teal.opacity(0.35), lineWidth: 1)
                        Annotation(zone.name, coordinate: zone.center.appleCoordinate, anchor: .bottom) {
                            Image(systemName: zone.name.lowercased() == "home" ? "house.fill" : "storefront.fill")
                                .font(.system(size: 21)).foregroundStyle(.white)
                                .frame(width: 39, height: 39).background(OrbitStyle.teal, in: Circle())
                        }
                    }
                    if snapshot.trail.count > 1 {
                        MapPolyline(coordinates: snapshot.trail.filter(\.isValid).map(\.appleCoordinate))
                            .stroke(OrbitStyle.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 7]))
                    }
                    if let point {
                        Annotation("Senior", coordinate: point) {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 31, weight: .bold))
                                .rotationEffect(.degrees(snapshot.validHeading ?? 0))
                                .foregroundStyle(OrbitStyle.teal)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .ignoresSafeArea()
            VStack(alignment: .leading) {
                Circle().fill(.white)
                    .shadow(color: .black.opacity(0.16), radius: 3)
                    .frame(width: 55, height: 55)
                    .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(OrbitStyle.teal))
                    .offset(y: -8)
                    .accessibilityLabel("Caregiver profile")
                Spacer(minLength: 0)
                if let snapshot, snapshot.isCurrent, let status = snapshot.status, !status.isEmpty {
                    Text(status).font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background {
                            Capsule().fill(.white)
                                .shadow(color: .black.opacity(0.16), radius: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 15)
                        .offset(y: -70)
                }
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        FloatingMapButton(symbol: "sparkle", label: "Agent", action: agent)
                        FloatingMapButton(symbol: "plus", label: "Add safe zone", action: {})
                            .disabled(true)
                        FloatingMapButton(symbol: "arrow.clockwise", label: "Refresh location", action: refresh)
                            .disabled(loading)
                    }
                }.padding(.bottom, 23)
                if snapshot == nil || snapshot?.isCurrent == false || message != nil {
                    Text(message ?? (snapshot == nil ? "Location is not available yet." : "Senior location is out of date."))
                        .font(.footnote).foregroundStyle(.primary)
                        .padding(12).frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 8)
                }
                SeniorLocationCard(profile: profile, snapshot: snapshot, navigate: navigate)
                    .padding(.bottom, 93)
            }.padding(.horizontal, 20).padding(.top, 4)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: snapshot?.recordedAt) { _, _ in focusOnSenior() }
        .onAppear { focusOnSenior() }
    }
    private func focusOnSenior() {
        guard let point else { return }
        let trail = snapshot?.trail.filter(\.isValid).map(\.appleCoordinate) ?? []
        let coordinates = trail + [point]
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2,
                                            longitude: (minLongitude + maxLongitude) / 2 + (maxLongitude - minLongitude) * 0.03)
        let trailWidth = CLLocation(latitude: center.latitude, longitude: minLongitude)
            .distance(from: CLLocation(latitude: center.latitude, longitude: maxLongitude))
        let trailHeight = CLLocation(latitude: minLatitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: maxLatitude, longitude: center.longitude))
        let visibleMeters = max(640, trailWidth * 1.5, trailHeight * 1.5)
        camera = .region(MKCoordinateRegion(center: center, latitudinalMeters: visibleMeters,
                                            longitudinalMeters: visibleMeters))
    }
}

private struct FloatingMapButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.black).frame(width: 48, height: 48)
                .background {
                    Circle().fill(.white)
                        .shadow(color: .black.opacity(0.126), radius: 5, y: 2)
                }
        }.accessibilityLabel(label)
    }
}

private struct SeniorLocationCard: View {
    let profile: ElderProfile
    let snapshot: ElderLocationSnapshot?
    let navigate: () -> Void
    @Environment(\.openURL) private var openURL
    private var canNavigate: Bool { snapshot?.isCurrent == true }
    private var canCall: Bool { PhoneNumber.isValid(profile.phone) }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 14) {
                ProfileAvatar(photo: profile.photo, size: 65)
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 8) {
                        if snapshot?.isCurrent == true {
                            Label("Normal", systemImage: "checkmark.shield")
                                .font(.system(size: 14, weight: .medium)).padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Color(red: 0.84, green: 0.91, blue: 0.80), in: Capsule())
                        } else { Text("Location unavailable").font(.caption).foregroundStyle(.secondary) }
                        if let battery = snapshot?.batteryPercent, (0...100).contains(battery) {
                            Label("\(battery)%", systemImage: "battery.100percent")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    guard canCall, let url = URL(string: "tel:\(PhoneNumber.normalized(profile.phone))") else { return }
                    openURL(url)
                } label: {
                    Image(systemName: "phone.fill").font(.system(size: 22)).foregroundStyle(.black)
                        .frame(width: 54, height: 54).background(Color(red: 0.82, green: 0.90, blue: 0.90), in: Circle())
                }.disabled(!canCall).accessibilityLabel("Call senior")
            }
            Rectangle().fill(.black.opacity(0.1)).frame(height: 1)
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 20)).foregroundStyle(.secondary)
                Text(snapshot?.address.flatMap { $0.isEmpty ? nil : $0 } ?? "Address unavailable")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: navigate) {
                    Label("Navigate", systemImage: "arrow.up.right")
                        .labelStyle(.titleAndIcon).font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white).padding(.horizontal, 14).frame(height: 42)
                        .background(OrbitStyle.teal, in: Capsule())
                }.disabled(!canNavigate)
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 23).fill(.white)
                .shadow(color: .black.opacity(0.168), radius: 8, y: 4)
        }
    }
}

struct WalkingNavigationPage: View {
    let snapshot: ElderLocationSnapshot?
    let name: String
    let end: () -> Void
    @StateObject private var model: WalkingNavigationModel
    @State private var camera: MapCameraPosition = .automatic
    init(snapshot: ElderLocationSnapshot?, name: String, end: @escaping () -> Void) {
        self.snapshot = snapshot; self.name = name; self.end = end
        _model = StateObject(wrappedValue: WalkingNavigationModel())
    }
    init(snapshot: ElderLocationSnapshot?, name: String, model: WalkingNavigationModel, end: @escaping () -> Void) {
        self.snapshot = snapshot; self.name = name; self.end = end
        _model = StateObject(wrappedValue: model)
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                if let route = model.route {
                    MapPolyline(coordinates: route.coordinates).stroke(OrbitStyle.teal, lineWidth: 6)
                }
                if let snapshot, snapshot.coordinate.isValid {
                    Marker(name, coordinate: snapshot.coordinate.appleCoordinate)
                }
            }.mapStyle(.standard(elevation: .flat)).ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: end) { Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold)).frame(width: 44, height: 44)
                        .background(.white, in: Capsule()) }
                        .accessibilityLabel("Close navigation")
                    Spacer()
                }.padding(.horizontal, 20).padding(.top, 12)
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Walking to \(name)").font(.title3.bold())
                    if model.loading { ProgressView("Finding a walking route…") }
                    else if let issue = model.issue {
                        Text(issue.localizedDescription).font(.subheadline)
                        Button("Try again") { Task { await model.plan(to: snapshot) } }
                    } else if let route = model.route {
                        Text("\(Self.distance(route.distanceMeters)) · \(Int(ceil(route.expectedSeconds / 60))) min")
                            .font(.headline).foregroundStyle(OrbitStyle.teal)
                        if route.steps.isEmpty { Text("Follow the highlighted route.") }
                        else {
                            ScrollView { VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top) {
                                        Text("\(index + 1).").foregroundStyle(OrbitStyle.teal)
                                        Text(step)
                                    }.font(.subheadline)
                                }
                            }}.frame(maxHeight: 170)
                        }
                    }
                    Button("End navigation", action: end)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .foregroundStyle(.white).background(OrbitStyle.teal, in: Capsule())
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
            }
        }.tint(OrbitStyle.teal)
        .task {
            await model.plan(to: snapshot)
            if let coordinates = model.route?.coordinates, !coordinates.isEmpty {
                let latitudes = coordinates.map(\.latitude), longitudes = coordinates.map(\.longitude)
                camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (latitudes.min()! + latitudes.max()!)/2,
                    longitude: (longitudes.min()! + longitudes.max()!)/2),
                    span: MKCoordinateSpan(latitudeDelta: max(0.004, (latitudes.max()! - latitudes.min()!)*1.4),
                                           longitudeDelta: max(0.004, (longitudes.max()! - longitudes.min()!)*1.4))))
            }
        }
    }
    private static func distance(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters.rounded())) m"
    }
}

#if DEBUG
private func locationPreview() -> ElderLocationSnapshot {
    LocationPreviewData.snapshot()
}
#Preview("Location") {
    var elder = ElderProfile(); elder.name = "Cuilan Liu"; elder.phone = "+8613800000000"
    return LocationPage(profile: elder, snapshot: locationPreview(), message: nil, loading: false,
                        refresh: {}, agent: {}, navigate: {})
}
#Preview("Location unavailable") {
    var elder = ElderProfile(); elder.name = "Cuilan Liu"
    return LocationPage(profile: elder, snapshot: nil, message: nil, loading: false,
                        refresh: {}, agent: {}, navigate: {})
}
#endif
