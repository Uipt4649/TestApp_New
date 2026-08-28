import MapKit
import SwiftUI

struct EventTimeSummary: View {
    let event: Event

    var body: some View {
        HStack(spacing: 14) {
            if let doorsAt = event.doorsAt {
                Label("開場 \(timeText(doorsAt))", systemImage: "door.left.hand.open")
            }
            Label("開演 \(timeText(event.date))", systemImage: "play.fill")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let event: Event
    var onEdit: (() -> Void)?

    @State private var mapItem: MKMapItem?
    @State private var isSearchingLocation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(event.title)
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                        Label(dateText, systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                        EventTimeSummary(event: event)
                    }

                    if let locationName = event.locationName, !locationName.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(locationName, systemImage: "mappin.and.ellipse")
                                .font(.headline)

                            if let mapItem {
                                let coordinate = mapItem.placemark.coordinate
                                Map(
                                    initialPosition: .region(
                                        MKCoordinateRegion(
                                            center: coordinate,
                                            span: MKCoordinateSpan(
                                                latitudeDelta: 0.012,
                                                longitudeDelta: 0.012
                                            )
                                        )
                                    )
                                ) {
                                    Marker(locationName, coordinate: coordinate)
                                }
                                .frame(height: 240)
                                .overlay(Rectangle().stroke(.white.opacity(0.55), lineWidth: 0.8))

                                Button {
                                    mapItem.openInMaps()
                                } label: {
                                    Label("iOS標準マップで開く", systemImage: "map.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .foregroundStyle(.white)
                                        .background(AppStyle.ink)
                                }
                                .buttonStyle(.plain)
                            } else if isSearchingLocation {
                                HStack {
                                    ProgressView()
                                    Text("会場の場所を確認中")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120)
                            } else {
                                ContentUnavailableView(
                                    "会場を特定できませんでした",
                                    systemImage: "map",
                                    description: Text("会場名を編集すると再検索できます")
                                )
                                .frame(minHeight: 170)
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .overlay(Rectangle().stroke(.white.opacity(0.48), lineWidth: 0.8))
                    }

                    if let details = event.details, !details.isEmpty {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if let sourceURL = event.sourceURL {
                        Link(destination: sourceURL) {
                            Label("公式情報を確認", systemImage: "safari")
                        }
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("予定の詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if let onEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("編集") { onEdit() }
                    }
                }
            }
            .task(id: event.locationName) {
                await resolveLocation()
            }
        }
    }

    private var dateText: String {
        event.date.formatted(
            Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "ja_JP"))
        )
    }

    private func resolveLocation() async {
        guard let locationName = event.locationName, !locationName.isEmpty else { return }
        isSearchingLocation = true
        defer { isSearchingLocation = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationName
        request.resultTypes = [.address, .pointOfInterest]
        let response = try? await MKLocalSearch(request: request).start()
        mapItem = response?.mapItems.first
    }
}
