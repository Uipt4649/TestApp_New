import SwiftUI
import MapKit

// MARK: - 1. Event Model
struct Event: Identifiable, Equatable {
    let id: UUID = UUID()
    var artistID: UUID
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

// MARK: - 2. Calendar View
struct CalendarView: View {
    @State private var selectedDate: Date? = Date()
    @State private var currentMonth: Date = Date()
    @Binding var events: [Event]
    
    @Binding var cards: [Card]
    @Binding var selectedArtistID: UUID?
    
    @State private var showAddEventSheet: Bool = false
    @State private var editingEvent: Event? = nil
    @State private var showChatSheet: Bool = false
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var currentArtistName: String {
        cards.first(where: { $0.id == selectedArtistID })?.artistName ?? "アーティスト"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- カレンダーヘッダー ---
                VStack(spacing: 16) {
                    HStack {
                        Button("<") { previousMonth() }
                        Spacer()
                        Text(monthYearString(currentMonth)).font(.title2).bold()
                        Spacer()
                        Button(">") { nextMonth() }
                    }
                    .padding(.horizontal)
                    
                    let weekdaySymbols = Calendar.current.shortWeekdaySymbols
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { day in
                            Text(day).frame(maxWidth: .infinity).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(daysInMonth(currentMonth), id: \.self) { date in
                            Button {
                                selectedDate = date
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(isSelected(date) ? Color.blue.opacity(0.3) : Color.clear)
                                        .cornerRadius(8)
                                    
                                    if !eventsForDate(date).isEmpty {
                                        Circle().fill(Color.red).frame(width: 6, height: 6)
                                    } else {
                                        Spacer().frame(height: 6)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // --- 予定リスト ---
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if let selectedDate = selectedDate {
                            Text("\(monthDayString(selectedDate)) の予定")
                                .font(.headline)
                        }
                        Spacer()
                        Button {
                            editingEvent = nil
                            showAddEventSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    if let selectedDate = selectedDate {
                        let dayEvents = eventsForDate(selectedDate)
                        
                        if dayEvents.isEmpty {
                            ContentUnavailableView("予定なし", systemImage: "calendar.badge.plus", description: Text("\(currentArtistName) の予定を＋から追加できます"))
                                .frame(maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(dayEvents) { event in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title).font(.body).bold()
                                        
                                        if let location = event.locationName, !location.isEmpty {
                                            Button {
                                                openMap(locationName: location)
                                            } label: {
                                                Label(location, systemImage: "mappin.and.ellipse")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingEvent = event
                                        showAddEventSheet = true
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteEvent(at: indexSet, in: dayEvents)
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle(currentArtistName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(cards) { card in
                            Button {
                                selectedArtistID = card.id
                            } label: {
                                HStack {
                                    Text(card.artistName)
                                    if selectedArtistID == card.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showChatSheet = true } label: {
                        ZStack {
                            Circle().fill(Color.blue).frame(width: 32, height: 32)
                            Image(systemName: "sparkles.bubble.fill").font(.system(size: 14)).foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showChatSheet) {
                ChatBotView(events: $events, selectedArtistID: selectedArtistID)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddEventSheet) {
                AddEventSheet(date: selectedDate ?? Date(), event: editingEvent, selectedArtistID: selectedArtistID) { newEvent in
                    if let editingEvent = editingEvent {
                        if let index = events.firstIndex(where: { $0.id == editingEvent.id }) {
                            events[index] = newEvent
                        }
                    } else {
                        events.append(newEvent)
                    }
                }
            }
        }
    }
    
    // --- 内部ヘルパー関数 ---
    func deleteEvent(at offsets: IndexSet, in dayEvents: [Event]) {
        for index in offsets {
            let eventToDelete = dayEvents[index]
            events.removeAll(where: { $0.id == eventToDelete.id })
        }
    }
    
    func openMap(locationName: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationName) { placemarks, error in
            if let placemark = placemarks?.first {
                let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
                mapItem.name = locationName
                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } else if let encodedName = locationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "http://maps.apple.com/?q=\(encodedName)") {
                UIApplication.shared.open(url)
            }
        }
    }

    func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
    }
    
    func isSelected(_ date: Date) -> Bool {
        guard let selectedDate else { return false }
        return Calendar.current.isDate(selectedDate, inSameDayAs: date)
    }
    
    func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }
    
    func monthDayString(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    func previousMonth() { if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) { currentMonth = newMonth } }
    func nextMonth() { if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) { currentMonth = newMonth } }
    
    func eventsForDate(_ date: Date) -> [Event] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.artistID == selectedArtistID }
    }
}

// MARK: - 3. ChatBotView (追加)
struct ChatBotView: View {
    @Environment(\.dismiss) var dismiss
    @State private var messages: [ChatMessage] = [ChatMessage(text: "情報を教えて！", isUser: false)]
    @State private var inputText = ""
    @Binding var events: [Event]
    var selectedArtistID: UUID?
    
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
        let textToSend = inputText
        messages.append(ChatMessage(text: textToSend, isUser: true))
        inputText = ""
        
        // API呼び出しロジック (既存)
        guard let url = URL(string: "http://127.0.0.1:8200/analyze") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": textToSend])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            do {
                let decoded = try JSONDecoder().decode(AIResult.self, from: data)
                DispatchQueue.main.async {
                    let aiResponse = decoded.is_event ? "「\(decoded.title ?? "")」を登録したよ！" : (decoded.details ?? "了解しました。")
                    messages.append(ChatMessage(text: aiResponse, isUser: false))
                    
                    if decoded.is_event, let title = decoded.title, let dateString = decoded.date {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                        if let date = formatter.date(from: dateString) {
                            let newEvent = Event(artistID: selectedArtistID ?? UUID(), date: date, title: title, details: decoded.details, locationName: decoded.location)
                            events.append(newEvent)
                        }
                    }
                }
            } catch { print("Error: \(error)") }
        }.resume()
    }
}

// MARK: - 4. AddEventSheet (追加)
struct AddEventSheet: View {
    @Environment(\.dismiss) var dismiss
    var date: Date
    var event: Event?
    var selectedArtistID: UUID?
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
                        let newEvent = Event(artistID: selectedArtistID ?? UUID(), date: date, title: title, details: details, locationName: locationName)
                        onAdd(newEvent)
                        dismiss()
                    }.disabled(title.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            }
            .onAppear {
                if let event = event {
                    title = event.title
                    details = event.details ?? ""
                    locationName = event.locationName ?? ""
                }
            }
        }
    }
}

// MARK: - 5. Helper Models
struct ChatMessage: Identifiable {
    let id = UUID(); let text: String; let isUser: Bool
}

struct AIResult: Codable {
    let is_event: Bool; let title: String?; let date: String?; let location: String?; let details: String?
}

// MARK: - Preview
struct CalendarPreviewContainer: View {
    @State var mockEvents: [Event] = []
    @State var mockCards: [Card] = []
    @State var selectedID: UUID?
    
    var body: some View {
        CalendarView(events: $mockEvents, cards: $mockCards, selectedArtistID: $selectedID)
    }
}

#Preview {
    CalendarPreviewContainer()
}
