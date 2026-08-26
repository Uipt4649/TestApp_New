import SwiftUI
import PhotosUI

struct Card: Identifiable, Equatable {
    var id: UUID = UUID()
    var artistName: String
    var image: UIImage?
    var description: String?
    var backgroundColor: Color
}

enum AppStyle {
    static let pagePadding: CGFloat = 20
    static let cardInset: CGFloat = 16
    static let hairline = Color.white.opacity(0.52)
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.12)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.92, green: 0.95, blue: 0.97)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 390, height: 390)
                .blur(radius: 80)
                .offset(x: 170, y: -270)

            Circle()
                .fill(Color.indigo.opacity(0.10))
                .frame(width: 330, height: 330)
                .blur(radius: 90)
                .offset(x: -190, y: 310)

            LinearGradient(
                colors: [.white.opacity(0.62), .clear, .white.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct GlassSurface: ViewModifier {
    var tint: Color = .white
    var opacity: Double = 0.10
    var isInteractive = false

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular
                    .tint(tint.opacity(opacity))
                    .interactive(isInteractive),
                in: Rectangle()
            )
            .overlay {
                Rectangle()
                    .stroke(AppStyle.hairline, lineWidth: 0.8)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.74), .white.opacity(0.05), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                    }
            }
            .clipShape(Rectangle())
    }
}

private extension View {
    func glassSurface(tint: Color = .white, opacity: Double = 0.10, isInteractive: Bool = false) -> some View {
        modifier(GlassSurface(tint: tint, opacity: opacity, isInteractive: isInteractive))
    }
}

struct CardView: View {
    let card: Card
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onOpenCalendar: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .scrollView(axis: .horizontal))
            let progress = min(max(frame.minX / max(frame.width, 1), -1), 1)

            cardBody
                .padding(.horizontal, AppStyle.cardInset)
                .rotation3DEffect(
                    .degrees(-progress * 86),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: progress > 0 ? .leading : .trailing,
                    perspective: 0.72
                )
                .scaleEffect(1 - abs(progress) * 0.035)
                .opacity(1 - abs(progress) * 0.16)
        }
        .containerRelativeFrame(.horizontal)
    }

    private var cardBody: some View {
        ZStack {
            cardArtwork

            LinearGradient(
                colors: [.black.opacity(0.04), .clear, .black.opacity(0.54)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text("OSHI PROFILE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.84))

                    Spacer()

                    actionButton(systemName: "pencil", action: onEdit)
                    actionButton(systemName: "trash", action: { showDeleteAlert = true })
                }
                .padding(16)

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.artistName)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .lineLimit(1)

                            Text(card.description?.isEmpty == false ? card.description! : "AIが最新情報と予定を整理します")
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.62))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.72))
                    }

                    Button(action: onOpenCalendar) {
                        HStack {
                            Label("予定を見る", systemImage: "calendar")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .foregroundStyle(.white)
                        .background(AppStyle.ink.opacity(0.88))
                        .overlay(Rectangle().stroke(.white.opacity(0.20), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .glassSurface(tint: card.backgroundColor, opacity: 0.09)
                .padding(12)
            }
        }
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.86), .white.opacity(0.22), .white.opacity(0.64)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: card.backgroundColor.opacity(0.18), radius: 28, y: 18)
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .alert("この推しカードを削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive, action: onDelete)
            Button("キャンセル", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var cardArtwork: some View {
        if let image = card.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [card.backgroundColor.opacity(0.92), card.backgroundColor.opacity(0.35), .white.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.20))
                    .frame(width: 280, height: 280)
                    .blur(radius: 8)
                    .offset(x: 110, y: -150)

                Text(String(card.artistName.prefix(1)).uppercased())
                    .font(.system(size: 190, weight: .thin, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
            }
        }
    }

    private func actionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(.white)
                .glassSurface(opacity: 0.06, isInteractive: true)
        }
        .buttonStyle(.plain)
    }
}

struct AddCardView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 18) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .light))
                    .frame(width: 58, height: 58)
                    .glassSurface(opacity: 0.12, isInteractive: true)

                VStack(spacing: 6) {
                    Text("推しを追加")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("名前を登録して、AIに予定を探してもらいましょう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(AppStyle.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassSurface(opacity: 0.16)
            .overlay {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 0.8, dash: [7, 7]))
                    .foregroundStyle(.primary.opacity(0.18))
            }
            .padding(.horizontal, AppStyle.cardInset)
        }
        .buttonStyle(.plain)
        .containerRelativeFrame(.horizontal)
    }
}

struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var artistName = ""
    @State private var description = ""
    @State private var backgroundColor: Color = .cyan
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?

    let onSave: (Card) -> Void
    var editingCard: Card?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        imagePicker
                        inputSection(title: "NAME") {
                            TextField("推しの名前", text: $artistName)
                                .font(.title3.weight(.medium))
                        }
                        inputSection(title: "MEMO") {
                            TextField("プロフィールやメモ（任意）", text: $description, axis: .vertical)
                                .lineLimit(3...6)
                        }
                        inputSection(title: "ACCENT") {
                            ColorPicker("カードの光の色", selection: $backgroundColor)
                        }
                    }
                    .padding(AppStyle.pagePadding)
                }
            }
            .navigationTitle(editingCard == nil ? "推しを追加" : "推しを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            Card(
                                id: editingCard?.id ?? UUID(),
                                artistName: artistName.trimmingCharacters(in: .whitespacesAndNewlines),
                                image: image,
                                description: description.isEmpty ? nil : description,
                                backgroundColor: backgroundColor
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let editingCard else { return }
                artistName = editingCard.artistName
                description = editingCard.description ?? ""
                backgroundColor = editingCard.backgroundColor
                image = editingCard.image
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let loadedImage = UIImage(data: data) {
                        image = loadedImage
                    }
                }
            }
        }
    }

    private var imagePicker: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [backgroundColor.opacity(0.62), .white.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .light))
                        Text("写真を選択")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(Rectangle().stroke(.white.opacity(0.66), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private func inputSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(opacity: 0.13)
    }
}

struct ContentView: View {
    @Binding var cards: [Card]
    @Binding var selectedArtistID: UUID?
    @Binding var selectedTab: Int

    @State private var showAddSheet = false
    @State private var editingCard: Card?
    @State private var visiblePageID: UUID?

    private let addCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 14) {
                    header

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(cards) { card in
                                CardView(
                                    card: card,
                                    onDelete: { delete(card) },
                                    onEdit: { edit(card) },
                                    onOpenCalendar: { openCalendar(for: card) }
                                )
                                .id(card.id)
                            }

                            AddCardView(action: addCard)
                                .id(addCardID)
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $visiblePageID)

                    pageIndicator
                }
                .padding(.bottom, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                AddCardSheet(
                    onSave: save,
                    editingCard: editingCard
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MY OSHI")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)
                Text("推しのすべてを、ひとつに。")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppStyle.ink)
            }

            Spacer()

            Button(action: addCard) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(AppStyle.ink)
                    .glassSurface(opacity: 0.16, isInteractive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppStyle.pagePadding)
        .padding(.top, 10)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(cards) { card in
                Capsule()
                    .fill(visiblePageID == card.id ? AppStyle.ink : AppStyle.ink.opacity(0.18))
                    .frame(width: visiblePageID == card.id ? 22 : 6, height: 4)
                    .animation(.easeOut(duration: 0.22), value: visiblePageID)
            }
            Circle()
                .stroke(AppStyle.ink.opacity(0.32), lineWidth: 1)
                .frame(width: 5, height: 5)
        }
        .frame(height: 8)
        .onAppear {
            if visiblePageID == nil {
                visiblePageID = cards.first?.id ?? addCardID
            }
        }
    }

    private func addCard() {
        editingCard = nil
        showAddSheet = true
    }

    private func edit(_ card: Card) {
        editingCard = card
        showAddSheet = true
    }

    private func save(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        } else {
            cards.append(card)
            visiblePageID = card.id
        }
    }

    private func delete(_ card: Card) {
        cards.removeAll { $0.id == card.id }
        if visiblePageID == card.id {
            visiblePageID = cards.first?.id ?? addCardID
        }
    }

    private func openCalendar(for card: Card) {
        selectedArtistID = card.id
        withAnimation(.easeInOut(duration: 0.24)) {
            selectedTab = 1
        }
    }
}

struct SelectView: View {
    @State private var events: [Event] = []
    @State private var logs: [LogEntry] = []
    @State private var cards: [Card] = []
    @State private var selectedArtistID: UUID?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView(cards: $cards, selectedArtistID: $selectedArtistID, selectedTab: $selectedTab)
                .tabItem { Label("ホーム", systemImage: "square.stack.3d.up.fill") }
                .tag(0)

            CalendarView(events: $events, cards: $cards, selectedArtistID: $selectedArtistID)
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(1)

            EventView(events: $events, cards: $cards)
                .tabItem { Label("予定", systemImage: "sparkles") }
                .tag(2)

            LogView(logs: $logs)
                .tabItem { Label("履歴", systemImage: "clock.arrow.circlepath") }
                .tag(3)
        }
        .tint(AppStyle.ink)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: cards) { _, updatedCards in
            guard selectedArtistID == nil else { return }
            selectedArtistID = updatedCards.first?.id
        }
    }
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var date: Date = Date()
}

struct LogView: View {
    @Binding var logs: [LogEntry]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if logs.isEmpty {
                    ContentUnavailableView("履歴はまだありません", systemImage: "clock.arrow.circlepath")
                } else {
                    List(logs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(log.message)
                            Text(log.date, formatter: logDateFormatter)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.white.opacity(0.30))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("履歴")
        }
    }
}

private let logDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#if DEBUG
#Preview {
    SelectView()
}
#endif
