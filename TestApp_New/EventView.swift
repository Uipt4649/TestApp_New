//
//  EventView.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2026/02/01.
//

import SwiftUI

struct EventView: View {
    @Binding var events: [Event]
    //誰の予定か判定するために、アーティストの情報も受け取る
    @Binding var cards: [Card]
    @State private var selectedEvent: Event?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if events.isEmpty {
                    ContentUnavailableView(
                        "予定がありません",
                        systemImage: "sparkles",
                        description: Text("AIが見つけた予定はここにまとまります")
                    )
                } else {
                    List {
                        ForEach(sortedEvents) { event in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    let artistName = cards.first(where: { $0.id == event.artistID })?.artistName ?? "不明"
                                    let artistColor = cards.first(where: { $0.id == event.artistID })?.backgroundColor ?? .gray

                                    Text(artistName.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                        .foregroundStyle(artistColor)

                                    Spacer()

                                    Text(smartDateLabel(for: event.date))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }

                                Text(event.title)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                                EventTimeSummary(event: event)

                                if let locationName = event.locationName, !locationName.isEmpty {
                                    Label(locationName, systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let details = event.details, !details.isEmpty {
                                    Text(details)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                            .listRowBackground(Color.white.opacity(0.24))
                            .listRowSeparatorTint(.white.opacity(0.52))
                        }
                        .onDelete(perform: deleteEvent)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("すべての予定")
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
    
    // 日付順にソート
    private var sortedEvents: [Event] {
        events.sorted { $0.date < $1.date }
    }
    
    // スワイプ削除
    private func deleteEvent(at offsets: IndexSet) {
        let sorted = sortedEvents
        let idsToDelete = offsets.map { sorted[$0].id }
        events.removeAll { idsToDelete.contains($0.id) }
    }
    
    // 日付表示
    private func smartDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今日" }
        else if calendar.isDateInTomorrow(date) { return "明日" }
        else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "M/d(E)" // 12/21(水) のような形式
            return formatter.string(from: date)
        }
    }
}
//#Preview {
//    EventView(events: .constant([]))
//}
