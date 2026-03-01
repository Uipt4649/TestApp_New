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
                            HStack {
                                //どのアーティストの予定かを表示
                                let artistName = cards.first(where: { $0.id == event.artistID })?.artistName ?? "不明"
                                let artistColor = cards.first(where: { $0.id == event.artistID })?.backgroundColor ?? .gray
                                
                                Text(artistName)
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(artistColor.opacity(0.2))
                                    .foregroundColor(artistColor)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text(smartDateLabel(for: event.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(event.title)
                                .font(.headline)
                            
                            if let details = event.details, !details.isEmpty {
                                Text(details)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(2) // 長い場合は省略
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteEvent)
                }
            }
            .navigationTitle("イベント一覧")
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

