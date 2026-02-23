//
//  EventRowView.swift
//  ThermoTask
//
//  Created by Alessio Faraci on 30/12/25.
//

import EventKit
import MapKit
import SwiftUI

/// A view that displays a single event as a card
struct EventRowView: View {
    let event: EKEvent
    var isSelected: Bool = false
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSelect: (() -> Void)?
    @State private var coordinate: CLLocationCoordinate2D?

    private var timeString: String {
        if event.isAllDay { return "All day" }
        guard let start = event.startDate, let end = event.endDate else { return "" }
        let fmt = DateFormatter.hourMinuteFormatter
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }

    private var cardColor: Color {
        if let cgColor = event.calendar.cgColor {
            return Color(cgColor: cgColor)
        }
        return Color.accentColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled Event")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !timeString.isEmpty {
                    Label(timeString, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(20)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if let coord = coordinate {
                mapPreview(coord: coord)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 1.5 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .contextMenu {
            Button { onEdit?() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) { onDelete?() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .task(id: event.eventIdentifier) {
            guard let location = event.location, !location.isEmpty, coordinate == nil else {
                return
            }
            let request = MKGeocodingRequest(addressString: location)
            guard let mapItem = try? await request?.mapItems.first else { return }
            coordinate = mapItem.location.coordinate
        }
    }

    @ViewBuilder
    private func mapPreview(coord: CLLocationCoordinate2D) -> some View {
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )

        ZStack {
            Map(position: .constant(.region(region))) {
                Marker("", coordinate: coord)
                    .tint(cardColor)
            }
            .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    var components = URLComponents()
                    components.scheme = "maps"
                    components.queryItems = [
                        URLQueryItem(name: "ll", value: "\(coord.latitude),\(coord.longitude)"),
                        URLQueryItem(name: "q", value: event.location ?? ""),
                    ]
                    if let url = components.url {
                        NSWorkspace.shared.open(url)
                    }
                }
        }
        .frame(width: 130, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
