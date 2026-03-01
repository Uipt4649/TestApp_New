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
                
                //カレンダーヘッダー
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
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 36, height: 36)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
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
                
                
                mapItem.openInMaps()
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
    @State private var messages: [ChatMessage] = [ChatMessage(text: "アーティスト名を教えてね", isUser: false)]
    @State private var inputText = ""
    @State private var isSearching = false
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
                        
                        
                        if isSearching {
                            HStack {
                                ProgressView()
                                    .padding(.leading, 12)
                                Text("調査中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
                
                HStack {
                    TextField("アーティスト名...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isSearching)
                    
                    Button {
                        sendMessage()
                    } label: {
                        if isSearching {
                            ProgressView()
                        } else {
                            Text("送信")
                        }
                    }
                    .disabled(inputText.isEmpty || isSearching)
                }
                .padding()
            }
            .navigationTitle("アシスタント")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
    
    func sendMessage() {
        let textToSend = inputText
        messages.append(ChatMessage(text: textToSend, isUser: true))
        inputText = ""
        isSearching = true
        
        if textToSend.count < 10 && !textToSend.contains("\n") {
            fetchOfficialEvents(artistName: textToSend)
        } else {
            analyzeWithGemini(text: textToSend)
        }
    }
    
    // 1. アーティスト名から一括検索
    func fetchOfficialEvents(artistName: String) {
        guard let encodedName = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://localhost:8201/artist_events?artist_name=\(encodedName)") else {
            isSearching = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isSearching = false
                guard let data = data else {
                    messages.append(ChatMessage(text: "通信エラーが発生したよ。", isUser: false))
                    return
                }
                do {
                    let decodedList = try JSONDecoder().decode([AIResult].self, from: data)
                    let validEvents = decodedList.filter { $0.is_event }
                    
                    if validEvents.isEmpty {
                        messages.append(ChatMessage(text: "\(artistName)の確定した予定は見は見つからなかったよ。公式サイトなどを確認してみてね。", isUser: false))
                        return
                    }
                    
                    var count = 0
                    for item in validEvents {
                        if let dateString = item.date, let date = parseDate(dateString) {
                            if !events.contains(where: { $0.title == item.title && Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                                let newEvent = Event(
                                    artistID: selectedArtistID ?? UUID(),
                                    date: date,
                                    title: item.title ?? "ライブ",
                                    details: item.details,
                                    locationName: item.location
                                )
                                events.append(newEvent)
                                count += 1
                            }
                        }
                    }
                    messages.append(ChatMessage(text: "\(artistName)のライブを\(count)件登録したよ！", isUser: false))
                } catch {
                    messages.append(ChatMessage(text: "解析に失敗しちゃった。", isUser: false))
                }
            }
        }.resume()
    }
    
    // 2. 自由テキスト解析 (POST /analyze)
    func analyzeWithGemini(text: String) {
        guard let url = URL(string: "http://localhost:8201/analyze") else {
            isSearching = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.isSearching = false
                guard let data = data else { return }
                do {
                    let decoded = try JSONDecoder().decode(AIResult.self, from: data)
                    let responseText = decoded.is_event ? "「\(decoded.title ?? "")」を登録したよ！" : (decoded.details ?? "解析できなかったよ。")
                    messages.append(ChatMessage(text: responseText, isUser: false))
                    
                    if decoded.is_event, let dateString = decoded.date, let date = parseDate(dateString) {
                        let newEvent = Event(
                            artistID: selectedArtistID ?? UUID(),
                            date: date,
                            title: decoded.title ?? "ライブ",
                            details: decoded.details,
                            locationName: decoded.location
                        )
                        events.append(newEvent)
                    }
                } catch {
                    messages.append(ChatMessage(text: "エラーが起きたよ。", isUser: false))
                }
            }
        }.resume()
    }
    
    func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) { return date }
        }
        return nil
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
    @State private var notifyTime = Date()
    @State private var isNotificationOn = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") { TextField("タイトル", text: $title) }
                Section("詳細") { TextEditor(text: $details).frame(height: 100) }
                Section("場所") { TextField("場所の名前", text: $locationName) }
                DatePicker(
                    "通知時間",
                    selection: $notifyTime,
                    displayedComponents: .hourAndMinute
                )
                Toggle("通知をONにする", isOn: $isNotificationOn)
                    .onChange(of: isNotificationOn) { newValue in
                        if newValue {
                            NotificationManager.shared.requestPermission { granted in
                                if !granted {
                                    isNotificationOn = false
                                }
                            }
                        }
                    }
                .datePickerStyle(.wheel)
                
            }
            .navigationTitle(event == nil ? "予定を追加" : "予定を編集")
            .toolbar {
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(event == nil ? "追加" : "保存") {
                        let newEvent = Event(
                            artistID: selectedArtistID ?? UUID(),
                            date: date,
                            title: title,
                            details: details,
                            locationName: locationName
                        )
                        let calendar = Calendar.current
                        
                        let eventDateComponents = calendar.dateComponents(
                            [.year, .month, .day],
                            from: newEvent.date
                        )
                        
                        let timeComponents = calendar.dateComponents(
                            [.hour, .minute],
                            from: notifyTime
                        )
                        
                        var combined = DateComponents()
                        combined.year = eventDateComponents.year
                        combined.month = eventDateComponents.month
                        combined.day = eventDateComponents.day
                        combined.hour = timeComponents.hour
                        combined.minute = timeComponents.minute
                        
                        let finalNotifyDate = calendar.date(from: combined)!
                        
                        onAdd(newEvent)

                        if isNotificationOn {
                            NotificationManager.shared.scheduleNotification(at: finalNotifyDate) { scheduledDate in
                                if let scheduledDate = scheduledDate {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "yyyy年M月d日 HH:mm"
                                    alertMessage = "\(formatter.string(from: scheduledDate)) に通知を送信します。"
                                } else {
                                    alertMessage = "通知の設定に失敗しました。"
                                }
                                
                                showAlert = true
                            }
                        } else {
                            dismiss()
                            
                        }
                        
                    }
                    .disabled(title.isEmpty)
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
            .alert("通知設定", isPresented: $showAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// MARK: - 5. Helper Models
struct ChatMessage: Identifiable {
    let id = UUID(); let text: String; let isUser: Bool
}
// Bandsintown APIからの複数イベント用
struct ArtistEvent: Codable {
    let is_event: Bool
    let title: String
    let date: String
    let location: String
    let details: String
}

struct AIResult: Codable {
    
    let is_event: Bool
    let title: String?
    let date: String?
    let location: String?
    let details: String?
    
    
    enum CodingKeys: String, CodingKey {
        case is_event, title, date, location, details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let boolVal = try? container.decode(Bool.self, forKey: .is_event) {
            is_event = boolVal
        } else if let stringVal = try? container.decode(String.self, forKey: .is_event) {
            is_event = (stringVal.lowercased() == "true")
        } else {
            is_event = false
        }
        title = try container.decodeIfPresent(String.self, forKey: .title)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        details = try container.decodeIfPresent(String.self, forKey: .details)
    }
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
