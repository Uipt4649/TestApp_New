//
//  CalendarView.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2025/12/23.
//
import SwiftUI
import MapKit

// MARK: - Event Model
struct Event: Identifiable, Equatable {
    let id: UUID = UUID()
    var date: Date
    var title: String
    var details: String?
    var locationName: String?
    var coordinate: CLLocationCoordinate2D?
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id &&
        lhs.date == rhs.date &&
        lhs.title == rhs.title &&
        lhs.details == rhs.details &&
        lhs.locationName == rhs.locationName
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()
    @Binding var events: [Event]
    @State private var showAddEventSheet: Bool = false
    @State private var editingEvent: Event? = nil
    @State private var showChatSheet: Bool = false

    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 月タイトル
                HStack {
                    Button("<") { previousMonth() }
                    Spacer()
                    Text(monthYearString(currentMonth))
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button(">") { nextMonth() }
                }
                .padding(.horizontal)

                // 曜日ヘッダー
                let weekdaySymbols = Calendar.current.shortWeekdaySymbols
                HStack {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day).frame(maxWidth: .infinity).font(.caption).foregroundColor(.secondary)
                    }
                }

                // 日付グリッド
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(daysInMonth(currentMonth), id: \.self) { date in
                        Button {
                            selectedDate = date
                            editingEvent = nil
                            showAddEventSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(8)
                                    .background(isSelected(date) ? Color.blue.opacity(0.3) : Color.clear)
                                    .cornerRadius(8)
                                
                                if !eventsForDate(date).isEmpty {
                                    Circle().fill(Color.red).frame(width: 6, height: 6)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding()
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        print("DEBUG: チャットボタンが押されました")
                        showChatSheet = true
                    } label: {
                        Image(systemName: "sparkles.bubble")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
            // チャット画面のシート
            .sheet(isPresented: $showChatSheet) {
                ChatBotView(events: $events)
                    .presentationDetents([.medium, .large])
            }
            // 予定追加のシート
            .sheet(isPresented: $showAddEventSheet) {
                AddEventSheet(date: selectedDate ?? Date(), event: editingEvent, onAdd: { newEvent in
                    events.append(newEvent)
                })
            }
        }
    }
  
    // MARK: - ヘルパー関数
    func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    func isSelected(_ date: Date) -> Bool {
        guard let selectedDate else { return false }
        return Calendar.current.isDate(selectedDate, inSameDayAs: date)
    }

    func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func eventsForDate(_ date: Date) -> [Event] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Chat Bot View
import SwiftUI

struct ChatBotView: View {
    @Environment(\.dismiss) var dismiss
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "推しの情報を教えて！", isUser: false)
    ]
    @State private var inputText = ""
    @Binding var events: [Event]

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.isUser { Spacer() }
                                Text(msg.text).padding(12)
                                    .background(msg.isUser ? Color.blue : Color.gray.opacity(0.15))
                                    .foregroundColor(msg.isUser ? .white : .primary)
                                    .cornerRadius(16)
                                if !msg.isUser { Spacer() }
                            }
                        }
                    }
                    .padding()
                }
                HStack {
                    TextField("AIに相談...", text: $inputText).textFieldStyle(.roundedBorder)
                    Button("送信") { sendMessage() }.disabled(inputText.isEmpty)
                }.padding()
            }
            .navigationTitle("アシスタント")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }

    func sendMessage() {
        let userMsg = ChatMessage(text: inputText, isUser: true)
        messages.append(userMsg)
        let textToSend = inputText
        inputText = ""

        // URLを8200に統一
        guard let url = URL(string: "http://127.0.0.1:8200/analyze") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": textToSend])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("【DEBUG】通信エラー: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else { return }
            
            // 生のデータを表示して確認
            if let rawString = String(data: data, encoding: .utf8) {
                print("【DEBUG】サーバーからの生データ: \(rawString)")
            }

            do {
                let decoded = try JSONDecoder().decode(AIResult.self, from: data)
                DispatchQueue.main.async {
                    let aiResponse = decoded.is_event ? "「\(decoded.title ?? "")」を登録したよ！" : (decoded.details ?? "了解しました。")
                    messages.append(ChatMessage(text: aiResponse, isUser: false))
                    
                    if decoded.is_event, let title = decoded.title, let dateString = decoded.date {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                        if let date = formatter.date(from: dateString) {
                            events.append(Event(date: date, title: title, details: decoded.details, locationName: decoded.location))
                        }
                    }
                }
            } catch {
                print("【DEBUG】解析エラー: \(error)")
            }
        }.resume()
    }
}

// MARK: - Add/Edit Sheet
struct AddEventSheet: View {
    @Environment(\.dismiss) var dismiss
    var date: Date
    var event: Event? = nil
    let onAdd: (Event) -> Void

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var locationName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") { TextField("タイトル", text: $title) }
                Section("詳細") { TextEditor(text: $details).frame(height: 100) }
                Section("場所") { TextField("場所の名前", text: $locationName) }
            }
            .navigationTitle(event == nil ? "予定を追加" : "予定を編集")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(event == nil ? "追加" : "保存") {
                        let newEvent = Event(date: date, title: title, details: details, locationName: locationName)
                        onAdd(newEvent)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                if let event {
                    title = event.title
                    details = event.details ?? ""
                    locationName = event.locationName ?? ""
                }
            }
        }
    }
}

// MARK: - Helper Models
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct AIResult: Codable {
    let is_event: Bool
    let title: String?
    let date: String?
    let location: String?
    let details: String?
}

// MARK: - Preview (修正ポイント)
struct CalendarPreviewContainer: View {
    @State var mockEvents: [Event] = []
    var body: some View {
        CalendarView(events: $mockEvents)
    }
}

#Preview {
    CalendarPreviewContainer()
}

