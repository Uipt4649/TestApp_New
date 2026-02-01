//
//  EventView.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2026/02/01.
//

import SwiftUI

struct EventView: View {
    @Binding var events: [Event]

    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    ContentUnavailableView(
                        "予定がありません",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("")
                    )
                } else {
                    ForEach(sortedEvents) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.title).font(.headline)
                            Text(smartDateLabel(for: event.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let details = event.details, !details.isEmpty {
                                Text(details).font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteEvent)
                }
            }
            .navigationTitle("イベント")
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

    // 日付表示を「今日」「明日」「その他」に変換
    private func smartDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今日" }
        else if calendar.isDateInTomorrow(date) { return "明日" }
        else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

#Preview {
    EventView(events: .constant([]))
}

