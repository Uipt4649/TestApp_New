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
        // coordinate は比較しない
    }
}

// MARK: - Calendar View
//struct CalendarView: View {
//    @State private var selectedDate: Date? = nil
//    @State private var currentMonth: Date = Date()
//    @Binding var events: [Event]  // ←Binding に変更
//    @State private var showAddEventSheet: Bool = false
//    @State private var editingEvent: Event? = nil
//    
//    let columns = Array(repeating: GridItem(.flexible()), count: 7) // 7列
//
//    var body: some View {
//        NavigationStack {
//            VStack(spacing: 16) {
//                // 月タイトル
//                HStack {
//                    Button("<") { previousMonth() }
//                    Spacer()
//                    Text(monthYearString(currentMonth))
//                        .font(.title2)
//                        .bold()
//                    Spacer()
//                    Button(">") { nextMonth() }
//                }
//                .padding(.horizontal)
//
//                // 曜日ヘッダー
//                let weekdaySymbols = Calendar.current.shortWeekdaySymbols
//                HStack {
//                    ForEach(weekdaySymbols, id: \.self) { day in
//                        Text(day).frame(maxWidth: .infinity)
//                    }
//                }
//
//                // 日付グリッド
//                LazyVGrid(columns: columns, spacing: 10) {
//                    ForEach(daysInMonth(currentMonth), id: \.self) { date in
//                        Button {
//                            selectedDate = date
//                            editingEvent = nil
//                            showAddEventSheet = true
//                        } label: {
//                            VStack(spacing: 4) {
//                                Text("\(Calendar.current.component(.day, from: date))")
//                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                                    .padding(8)
//                                    .background(isSelected(date) ? Color.blue.opacity(0.3) : Color.clear)
//                                    .cornerRadius(8)
//                                
//                                // その日のイベントがあるか表示
//                                if !eventsForDate(date).isEmpty {
//                                    Circle().fill(Color.red).frame(width: 6, height: 6)
//                                }
//                            }
//                        }
//                    }
//                }
//                .frame(maxHeight: .infinity)
//            }
//            .padding()
//            .navigationTitle("カレンダー")
//            .navigationBarTitleDisplayMode(.inline)
//            .sheet(isPresented: $showAddEventSheet) {
//                AddEventSheet(
//                    date: selectedDate ?? Date(),
//                    event: editingEvent,
//                    onAdd: { newEvent in
//                        if let editing = editingEvent {
//                            if let index = events.firstIndex(where: { $0.id == editing.id }) {
//                                events[index] = newEvent
//                            }
//                        } else {
//                            events.append(newEvent)
//                        }
//                    }
//                )
//            }
//        }
//    }

// MARK: - Calendar View (右上ボタン版)
struct CalendarView: View {
    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()
    @Binding var events: [Event]
    @State private var showAddEventSheet: Bool = false
    @State private var editingEvent: Event? = nil
    @State private var showChatSheet: Bool = false // チャット用フラグ

    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 月タイトル（ここは既存のまま）
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
            // ★ 右上にボタンを配置するツールバー
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showChatSheet = true
                    } label: {
                        Image(systemName: "sparkles.bubble")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
            // ★ チャット画面の呼び出し
            .sheet(isPresented: $showChatSheet) {
                ChatBotView(events: $events)
                    .presentationDetents([.medium, .large])
            }
            // (既存の AddEventSheet はそのまま)
            .sheet(isPresented: $showAddEventSheet) {
                AddEventSheet(date: selectedDate ?? Date(), event: editingEvent, onAdd: { newEvent in
                    events.append(newEvent)
                })
            }
        }
    }
  
    // MARK: - ヘルパー
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

// MARK: - Add/Edit Event Sheet
struct AddEventSheet: View {
    @Environment(\.dismiss) var dismiss
    var date: Date
    var event: Event? = nil
    let onAdd: (Event) -> Void

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var locationName: String = ""
    @State private var coordinate: CLLocationCoordinate2D? = nil

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
                        let newEvent = Event(date: date, title: title, details: details, locationName: locationName, coordinate: coordinate)
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
                    coordinate = event.coordinate
                }
            }
        }
    }
}

// MARK: - Chat Bot View
struct ChatBotView: View {
    @Environment(\.dismiss) var dismiss
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "推しの最新情報や予定を追加", isUser: false)
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
                                Text(msg.text)
                                    .padding(12)
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
                    TextField("AIに相談...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                    Button("送信") {
                        sendMessage()
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("推し活アシスタント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    func sendMessage() {
        let userMsg = ChatMessage(text: inputText, isUser: true)
        messages.append(userMsg)
        
        let currentText = inputText
        inputText = ""

        // ここで FastAPI を呼び出す（後のステップで実装）
        // とりあえず擬似返信
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            messages.append(ChatMessage(text: "「\(currentText)」ですね。解析してカレンダーを確認します", isUser: false))
        }
    }
}

// メッセージの型
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}



// MARK: - Preview
#Preview {
    CalendarView(events: .constant([]))
}

