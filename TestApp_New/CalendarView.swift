import SwiftUI
import MapKit

// MARK: - 1. Event Model
struct Event: Identifiable, Equatable {
    var id: UUID = UUID()
    var artistID: UUID
    var date: Date
    var doorsAt: Date? = nil
    var title: String
    var details: String?
    var locationName: String?
    var sourceURL: URL? = nil
    var coordinate: CLLocationCoordinate2D?
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id &&
        lhs.date == rhs.date &&
        lhs.doorsAt == rhs.doorsAt &&
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
    @State private var viewingEvent: Event?

    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    //西暦を算出
    var calender = Calendar(identifier: .gregorian)
    
    
    
    
    var currentArtistName: String {
        cards.first(where: { $0.id == selectedArtistID })?.artistName ?? "アーティスト"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 14) {
                    VStack(spacing: 16) {
                        HStack {
                            monthButton(systemName: "chevron.left", action: previousMonth)
                            Spacer()
                            VStack(spacing: 3) {
                                Text("CALENDAR")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.8)
                                    .foregroundStyle(.secondary)
                                Text(monthYearString(currentMonth))
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                            }
                            Spacer()
                            monthButton(systemName: "chevron.right", action: nextMonth)
                        }

                        let weekdaySymbols = Calendar.current.shortWeekdaySymbols
                        HStack {
                            ForEach(weekdaySymbols, id: \.self) { day in
                                Text(day.uppercased())
                                    .frame(maxWidth: .infinity)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(daysInMonth(currentMonth), id: \.self) { date in
                                Button {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        selectedDate = date
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("\(Calendar.current.component(.day, from: date))")
                                            .font(.system(size: 14, weight: isSelected(date) ? .bold : .regular))
                                            .frame(width: 34, height: 32)
                                            .foregroundStyle(isSelected(date) ? .white : .primary)
                                            .background(isSelected(date) ? AppStyle.ink : .clear)

                                        Circle()
                                            .fill(eventsForDate(date).isEmpty ? .clear : Color.cyan)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().stroke(.white.opacity(0.56), lineWidth: 0.8))
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            if let selectedDate {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(monthDayString(selectedDate))
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    Text("\(currentArtistName) の予定")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                editingEvent = nil
                                showAddEventSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(.white)
                                    .background(AppStyle.ink)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)

                        if let selectedDate {
                            let dayEvents = eventsForDate(selectedDate)
                            if dayEvents.isEmpty {
                                ContentUnavailableView(
                                    "予定はありません",
                                    systemImage: "calendar.badge.plus",
                                    description: Text("＋から追加するか、AIに探してもらえます")
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List {
                                    ForEach(dayEvents) { event in
                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(event.title)
                                                .font(.body.weight(.semibold))
                                            EventTimeSummary(event: event)
                                            if let location = event.locationName, !location.isEmpty {
                                                Label(location, systemImage: "mappin.and.ellipse")
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                        .listRowBackground(Color.white.opacity(0.18))
                                        .onTapGesture {
                                            viewingEvent = event
                                        }
                                    }
                                    .onDelete { indexSet in
                                        deleteEvent(at: indexSet, in: dayEvents)
                                    }
                                }
                                .listStyle(.plain)
                                .scrollContentBackground(.hidden)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().stroke(.white.opacity(0.44), lineWidth: 0.7))
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 10)
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
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.white)
                            .background(AppStyle.ink)
                    }
                }
            }
            .sheet(isPresented: $showChatSheet) {
                ChatBotView(
                    events: $events,
                    selectedArtistID: selectedArtistID
                ) { eventDate in
                    selectedDate = eventDate
                    currentMonth = eventDate
                }
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
            .sheet(item: $viewingEvent) { event in
                EventDetailView(event: event) {
                    viewingEvent = nil
                    editingEvent = event
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showAddEventSheet = true
                    }
                }
            }
        }
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.28))
                .overlay(Rectangle().stroke(.white.opacity(0.48), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }
    
    // --- 内部ヘルパー関数 ---
    func deleteEvent(at offsets: IndexSet, in dayEvents: [Event]) {
        for index in offsets {
            let eventToDelete = dayEvents[index]
            events.removeAll(where: { $0.id == eventToDelete.id })
        }
    }
    
    func openMap(locationName: String) {
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = locationName
            request.resultTypes = [.address, .pointOfInterest]

            if let response = try? await MKLocalSearch(request: request).start(),
               let mapItem = response.mapItems.first {
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
    @State private var messages: [ChatMessage]
    @State private var inputText = ""
    @State private var isSearching = false
    @Binding var events: [Event]
    var selectedArtistID: UUID?
    let onEventsAdded: (Date) -> Void
    private let apiClient = ChatbotAPIClient()

    init(
        events: Binding<[Event]>,
        selectedArtistID: UUID?,
        onEventsAdded: @escaping (Date) -> Void = { _ in }
    ) {
        _events = events
        self.selectedArtistID = selectedArtistID
        self.onEventsAdded = onEventsAdded
        _messages = State(
            initialValue: ChatHistoryStore.load()
        )
    }

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
                            HStack { ProgressView().padding(.leading, 12); Text("予定を確認中...").font(.caption).foregroundColor(.secondary); Spacer() }
                        }
                    }.padding()
                }
                
                HStack {
                    TextField("アーティスト名や予定...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isSearching)
                    Button("送信") { sendMessage() }
                        .disabled(inputText.isEmpty || isSearching)
                }.padding()
            }
            .navigationTitle("AIアシスタント")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appendMessage(ChatMessage(text: text, isUser: true))
        inputText = ""
        isSearching = true
        Task {
            await fetchEvents(text: text)
        }
    }

    private func fetchEvents(text: String) async {
        guard let selectedArtistID else {
            isSearching = false
            appendMessage(ChatMessage(text: "先に推しを選択してください。", isUser: false))
            return
        }

        defer { isSearching = false }
        do {
            let response = try await apiClient.findEvents(message: text)
            var addedCount = 0
            var addedDates: [Date] = []
            var existingDates: [Date] = []
            var confirmationCandidates: [String] = []
            for backendEvent in response.events {
                if backendEvent.requiresConfirmation == true {
                    confirmationCandidates.append(
                        "\(backendEvent.title)\n\(backendEvent.startAt)\n\(backendEvent.sourceURL)"
                    )
                    continue
                }
                guard let date = backendEvent.date else { continue }
                let isDuplicate = events.contains { existingEvent in
                    existingEvent.artistID == selectedArtistID
                        && existingEvent.title == backendEvent.title
                        && Calendar.current.isDate(existingEvent.date, inSameDayAs: date)
                        && existingEvent.locationName == backendEvent.locationName
                }
                if isDuplicate {
                    existingDates.append(date)
                    continue
                }

                events.append(
                    Event(
                        artistID: selectedArtistID,
                        date: date,
                        doorsAt: backendEvent.doorsDate,
                        title: backendEvent.title,
                        details: backendEvent.eventDetails,
                        locationName: backendEvent.locationName,
                        sourceURL: URL(string: backendEvent.sourceURL)
                    )
                )
                addedCount += 1
                addedDates.append(date)
            }

            let destinationDate = (addedDates + existingDates).min()
            if let destinationDate {
                onEventsAdded(destinationDate)
            }
            let resultMessage: String
            if addedCount > 0 {
                resultMessage = "\(response.message) カレンダーに\(addedCount)件追加し、該当月を表示しました。"
            } else if !existingDates.isEmpty {
                resultMessage = "\(response.message) すべて登録済みです。該当月を表示しました。"
            } else if !response.events.isEmpty && confirmationCandidates.isEmpty {
                resultMessage = "\(response.message) 日付を読み取れず、カレンダーへ追加できませんでした。"
            } else {
                resultMessage = response.message
            }
            appendMessage(ChatMessage(text: resultMessage, isUser: false))
            if !confirmationCandidates.isEmpty {
                appendMessage(
                    ChatMessage(
                        text: "AI検索の要確認候補:\n\n" + confirmationCandidates.joined(separator: "\n\n"),
                        isUser: false
                    )
                )
            }
            if !response.warnings.isEmpty {
                appendMessage(ChatMessage(text: response.warnings.joined(separator: "\n"), isUser: false))
            }
        } catch {
            appendMessage(
                ChatMessage(
                    text: error.localizedDescription,
                    isUser: false
                )
            )
        }
    }

    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        ChatHistoryStore.save(messages)
    }
}

//struct ChatBotView: View {
//    @Environment(\.dismiss) var dismiss
//    @State private var messages: [ChatMessage] = [ChatMessage(text: "アーティスト名を教えてね", isUser: false)]
//    @State private var inputText = ""
//    @State private var isSearching = false
//    @Binding var events: [Event]
//    var selectedArtistID: UUID?
//    
//    var body: some View {
//        NavigationStack {
//            VStack {
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 12) {
//                        ForEach(messages) { msg in
//                            HStack {
//                                if msg.isUser { Spacer() }
//                                Text(msg.text).padding(12)
//                                    .background(msg.isUser ? Color.blue : Color.gray.opacity(0.15))
//                                    .foregroundColor(msg.isUser ? .white : .primary)
//                                    .cornerRadius(16)
//                                if !msg.isUser { Spacer() }
//                            }
//                        }
//                        
//                        
//                        if isSearching {
//                            HStack {
//                                ProgressView()
//                                    .padding(.leading, 12)
//                                Text("調査中...")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                Spacer()
//                            }
//                            .padding(.vertical, 4)
//                        }
//                    }
//                    .padding()
//                }
//                
//                HStack {
//                    TextField("アーティスト名...", text: $inputText)
//                        .textFieldStyle(.roundedBorder)
//                        .disabled(isSearching)
//                    
//                    Button {
//                        sendMessage()
//                    } label: {
//                        if isSearching {
//                            ProgressView()
//                        } else {
//                            Text("送信")
//                        }
//                    }
//                    .disabled(inputText.isEmpty || isSearching)
//                }
//                .padding()
//            }
//            .navigationTitle("アシスタント")
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
//        }
//    }
//    
//    func sendMessage() {
//        let textToSend = inputText
//        messages.append(ChatMessage(text: textToSend, isUser: true))
//        inputText = ""
//        isSearching = true
//        
//        if textToSend.count < 10 && !textToSend.contains("\n") {
//            fetchOfficialEvents(artistName: textToSend)
//        } else {
//            analyzeWithGemini(text: textToSend)
//        }
//    }
//    
//    // 1. アーティスト名から一括検索
//    func fetchOfficialEvents(artistName: String) {
//        guard let encodedName = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
//              let url = URL(string: "http://localhost:8201/artist_events?artist_name=\(encodedName)") else {
//            isSearching = false
//            return
//        }
//        
//        URLSession.shared.dataTask(with: url) { data, _, error in
//            DispatchQueue.main.async {
//                self.isSearching = false
//                guard let data = data else {
//                    messages.append(ChatMessage(text: "通信エラーが発生したよ。", isUser: false))
//                    return
//                }
//                do {
//                    let decodedList = try JSONDecoder().decode([AIResult].self, from: data)
//                    let validEvents = decodedList.filter { $0.is_event }
//                    
//                    if validEvents.isEmpty {
//                        messages.append(ChatMessage(text: "\(artistName)の確定した予定は見は見つからなかったよ。公式サイトなどを確認してみてね。", isUser: false))
//                        return
//                    }
//                    
//                    var count = 0
//                    for item in validEvents {
//                        if let dateString = item.date, let date = parseDate(dateString) {
//                            if !events.contains(where: { $0.title == item.title && Calendar.current.isDate($0.date, inSameDayAs: date) }) {
//                                let newEvent = Event(
//                                    artistID: selectedArtistID ?? UUID(),
//                                    date: date,
//                                    title: item.title ?? "ライブ",
//                                    details: item.details,
//                                    locationName: item.location
//                                )
//                                events.append(newEvent)
//                                count += 1
//                            }
//                        }
//                    }
//                    messages.append(ChatMessage(text: "\(artistName)のライブを\(count)件登録したよ！", isUser: false))
//                } catch {
//                    messages.append(ChatMessage(text: "解析に失敗しちゃった。", isUser: false))
//                }
//            }
//        }.resume()
//    }
//    
//    // 2. 自由テキスト解析 (POST /analyze)
//    func analyzeWithGemini(text: String) {
//        guard let url = URL(string: "http://localhost:8201/analyze") else {
//            isSearching = false
//            return
//        }
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])
//        
//        URLSession.shared.dataTask(with: request) { data, _, _ in
//            DispatchQueue.main.async {
//                self.isSearching = false
//                guard let data = data else { return }
//                do {
//                    let decoded = try JSONDecoder().decode(AIResult.self, from: data)
//                    let responseText = decoded.is_event ? "「\(decoded.title ?? "")」を登録したよ！" : (decoded.details ?? "解析できなかったよ。")
//                    messages.append(ChatMessage(text: responseText, isUser: false))
//                    
//                    if decoded.is_event, let dateString = decoded.date, let date = parseDate(dateString) {
//                        let newEvent = Event(
//                            artistID: selectedArtistID ?? UUID(),
//                            date: date,
//                            title: decoded.title ?? "ライブ",
//                            details: decoded.details,
//                            locationName: decoded.location
//                        )
//                        events.append(newEvent)
//                    }
//                } catch {
//                    messages.append(ChatMessage(text: "エラーが起きたよ。", isUser: false))
//                }
//            }
//        }.resume()
//    }
//    
//    func parseDate(_ dateString: String) -> Date? {
//        let formatter = DateFormatter()
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
//        for format in formats {
//            formatter.dateFormat = format
//            if let date = formatter.date(from: dateString) { return date }
//        }
//        return nil
//    }
//}

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
    @State private var eventStartTime = Date()
    @State private var doorsTime = Date()
    @State private var hasDoorsTime = false
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
                Section("時間") {
                    DatePicker(
                        "開演",
                        selection: $eventStartTime,
                        displayedComponents: .hourAndMinute
                    )
                    Toggle("開場時間を設定", isOn: $hasDoorsTime)
                    if hasDoorsTime {
                        DatePicker(
                            "開場",
                            selection: $doorsTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
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
                        let startDate = combinedDate(day: date, time: eventStartTime)
                        let doorsDate = hasDoorsTime
                            ? combinedDate(day: date, time: doorsTime)
                            : nil
                        let newEvent = Event(
                            id: event?.id ?? UUID(),
                            artistID: event?.artistID ?? selectedArtistID ?? UUID(),
                            date: startDate,
                            doorsAt: doorsDate,
                            title: title,
                            details: details,
                            locationName: locationName,
                            sourceURL: event?.sourceURL
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
                    eventStartTime = event.date
                    if let doorsAt = event.doorsAt {
                        doorsTime = doorsAt
                        hasDoorsTime = true
                    }
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

    private func combinedDate(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var components = dayComponents
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components) ?? day
    }
}

// MARK: - 5. Helper Models
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let isUser: Bool

    init(id: UUID = UUID(), text: String, isUser: Bool) {
        self.id = id
        self.text = text
        self.isUser = isUser
    }
}

private enum ChatHistoryStore {
    private static let storageKey = "chatHistory.v1"
    private static let welcomeMessage = ChatMessage(
        text: "アーティスト名やイベント情報を教えてね",
        isUser: false
    )

    static func load() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
              !messages.isEmpty else {
            return [welcomeMessage]
        }
        return messages
    }

    static func save(_ messages: [ChatMessage]) {
        guard let data = try? JSONEncoder().encode(Array(messages.suffix(100))) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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

#if DEBUG
#Preview {
    CalendarPreviewContainer()
}
#endif
