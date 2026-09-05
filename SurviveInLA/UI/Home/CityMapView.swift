import MapKit
import SwiftUI

struct CityMapView: View {
    @Bindable var store: GameStore
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.93, longitude: -118.16),
            span: MKCoordinateSpan(latitudeDelta: 0.62, longitudeDelta: 0.88)
        )
    )

    private var markerPresentations: [DistrictMarkerPresentation] {
        GameContent.districts.map { district in
            DistrictMarkerPresentation(
                district: district,
                isCurrent: district.id == store.session.currentDistrictID,
                isSelected: store.selectedAction == .trading
                    && district.id == store.selectedDestinationID
            )
        }
    }

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            ForEach(markerPresentations) { presentation in
                let district = presentation.district
                Annotation(district.name, coordinate: district.coordinate, anchor: .bottom) {
                    Button {
                        guard store.selectedAction == .trading else { return }
                        withAnimation(.snappy) {
                            store.select(district.id)
                        }
                    } label: {
                        DistrictMarker(
                            district: district,
                            isCurrent: presentation.isCurrent,
                            isSelected: presentation.isSelected
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .flat,
                emphasis: .muted,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
        .onChange(of: store.session.currentDistrictID) { _, districtID in
            centerMap(on: districtID)
        }
        .overlay {
            Color.black.opacity(0.16)
                .allowsHitTesting(false)
        }
    }

    private func centerMap(on districtID: District.ID) {
        let destination = GameContent.district(districtID)
        let span = visibleRegion?.span
            ?? MKCoordinateSpan(latitudeDelta: 0.62, longitudeDelta: 0.88)

        withAnimation(.easeInOut(duration: 0.65)) {
            cameraPosition = .region(
                MKCoordinateRegion(center: destination.coordinate, span: span)
            )
        }
    }
}

private struct DistrictMarkerPresentation: Identifiable {
    let district: District
    let isCurrent: Bool
    let isSelected: Bool

    var id: String {
        if isCurrent {
            return "\(district.id.rawValue)-current"
        }
        return "\(district.id.rawValue)-selected-\(isSelected)"
    }
}

private struct DistrictMarker: View {
    let district: District
    let isCurrent: Bool
    let isSelected: Bool

    private var keepsLabelVisible: Bool {
        isCurrent || isSelected
    }

    var body: some View {
        VStack(spacing: 4) {
            if keepsLabelVisible {
                VStack(spacing: 0) {
                    Text(district.name)
                        .font(.caption2.weight(.bold))
                    if isSelected {
                        Text(district.englishName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThickMaterial, in: Capsule())
            }

            if isCurrent {
                CurrentLocationPin()
            } else {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.snappy, value: isSelected)
        .accessibilityLabel("\(district.fullName)\(isCurrent ? "，当前位置" : "")")
    }
}

private struct CurrentLocationPin: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var verticalOffset: CGFloat = -140
    @State private var pinOpacity = 0.0
    @State private var landingRingScale = 0.35
    @State private var landingRingOpacity = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .stroke(AppTheme.coralSoft.opacity(landingRingOpacity), lineWidth: 3)
                .frame(width: 34, height: 13)
                .scaleEffect(landingRingScale)
                .offset(y: 3)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 42, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, AppTheme.coral)
                .shadow(color: .black.opacity(0.5), radius: 7, y: 5)
                .offset(y: verticalOffset)
                .opacity(pinOpacity)
        }
        .frame(width: 52, height: 48, alignment: .bottom)
        .task {
            guard !reduceMotion else {
                verticalOffset = 0
                pinOpacity = 1
                return
            }

            await Task.yield()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                verticalOffset = 0
                pinOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(300))
            landingRingOpacity = 0.9
            withAnimation(.easeOut(duration: 0.5)) {
                landingRingScale = 1.8
                landingRingOpacity = 0
            }
        }
        .accessibilityHidden(true)
    }
}
