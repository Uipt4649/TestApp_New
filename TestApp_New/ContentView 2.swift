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
            let width = geometry.size.width
            let height = geometry.size.height

            if width.isFinite, height.isFinite, width > 1, height > 1 {
                let photoHeight = min(max(height * 0.52, 220), max(height - 210, 220))
                cardBody(width: width, height: height, photoHeight: photoHeight)
            } else {
                Color.clear
            }
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private func cardBody(width: CGFloat, height: CGFloat, photoHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                photoArea(width: width, height: photoHeight)

                HStack(spacing: 8) {
                    actionButton(systemName: "pencil", label: "編集", action: onEdit)
                    actionButton(systemName: "trash", label: "削除", action: { showDeleteAlert = true })
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(card.artistName)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let description = card.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 12)

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
                    .background(AppStyle.ink.opacity(0.90))
                    .overlay(Rectangle().stroke(.white.opacity(0.20), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial)
            .background(card.backgroundColor.opacity(0.10))
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.24))
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
        .alert("この推しカードを削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive, action: onDelete)
            Button("キャンセル", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func photoArea(width: CGFloat, height: CGFloat) -> some View {
        if let image = card.image {
            ZStack {
                LinearGradient(
                    colors: [card.backgroundColor.opacity(0.25), .white.opacity(0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
            }
            .frame(width: width, height: height)
            .clipped()
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
                    .font(.system(size: min(width, height) * 0.48, weight: .thin, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }

    private func actionButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 42, height: 42)
                .foregroundStyle(.white)
                .background(AppStyle.ink.opacity(0.66))
                .glassEffect(
                    .regular.tint(AppStyle.ink.opacity(0.28)),
                    in: Rectangle()
                )
                .overlay(Rectangle().stroke(.white.opacity(0.42), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
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

private struct OshiIconCloud: View {
    let cards: [Card]
    let onSelect: (Card) -> Void

    @State private var isFloating = false
    @State private var iconOffsets: [UUID: CGSize] = [:]
    @State private var draggingCardID: UUID?
    @State private var dragOrigin: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let positions = hexagonalPositions(count: cards.count)
            let unit = layoutUnit(for: positions, in: geometry.size)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let point = positions[index]
                    let size = iconSize(for: index, unit: unit)
                    let basePosition = CGPoint(
                        x: center.x + point.x * unit,
                        y: center.y + point.y * unit
                    )
                    let floatingOffset = CGSize(
                        width: isFloating
                            ? CGFloat((index % 3) - 1) * 2.5
                            : CGFloat(1 - (index % 3)) * 2.5,
                        height: isFloating
                            ? CGFloat(index.isMultiple(of: 2) ? -5 : 4)
                            : CGFloat(index.isMultiple(of: 2) ? 4 : -5)
                    )

                    icon(for: card, size: size)
                    .contentShape(Circle())
                    .onTapGesture { onSelect(card) }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                if draggingCardID != card.id {
                                    draggingCardID = card.id
                                    dragOrigin = iconOffsets[card.id] ?? .zero
                                }
                                iconOffsets[card.id] = clampedOffset(
                                    CGSize(
                                        width: dragOrigin.width + value.translation.width,
                                        height: dragOrigin.height + value.translation.height
                                    ),
                                    from: basePosition,
                                    iconSize: size,
                                    canvasSize: geometry.size
                                )
                            }
                            .onEnded { _ in
                                draggingCardID = nil
                            }
                    )
                    .accessibilityLabel(card.artistName)
                    .accessibilityAddTraits(.isButton)
                    .position(basePosition)
                    .offset(
                        x: (iconOffsets[card.id]?.width ?? 0) + floatingOffset.width,
                        y: (iconOffsets[card.id]?.height ?? 0) + floatingOffset.height
                    )
                    .zIndex(draggingCardID == card.id ? 1_000 : Double(cards.count - index))
                    .animation(
                        .easeInOut(duration: 2.8 + Double(index % 4) * 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.06),
                        value: isFloating
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .clipped()
        .onAppear { isFloating = true }
    }

    private func iconSize(for index: Int, unit: CGFloat) -> CGFloat {
        if index == 0 { return unit * 1.02 }
        if index < 7 { return unit * 0.94 }
        return unit * 0.86
    }

    private func hexagonalPositions(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        var points = [CGPoint.zero]
        let directions = [
            (q: -1, r: 1), (q: -1, r: 0), (q: 0, r: -1),
            (q: 1, r: -1), (q: 1, r: 0), (q: 0, r: 1)
        ]
        var ring = 1

        while points.count < count {
            var q = ring
            var r = 0
            for direction in directions {
                for _ in 0..<ring where points.count < count {
                    points.append(
                        CGPoint(
                            x: CGFloat(q) + CGFloat(r) * 0.5,
                            y: CGFloat(r) * 0.866
                        )
                    )
                    q += direction.q
                    r += direction.r
                }
            }
            ring += 1
        }
        return points
    }

    private func layoutUnit(for positions: [CGPoint], in size: CGSize) -> CGFloat {
        let maxX = positions.map { abs($0.x) }.max() ?? 0
        let maxY = positions.map { abs($0.y) }.max() ?? 0
        let horizontalUnit = (size.width - 24) / max(2 * maxX + 1.12, 1)
        let verticalUnit = (size.height - 24) / max(2 * maxY + 1.12, 1)
        return min(horizontalUnit, verticalUnit, 92)
    }

    private func clampedOffset(
        _ offset: CGSize,
        from basePosition: CGPoint,
        iconSize: CGFloat,
        canvasSize: CGSize
    ) -> CGSize {
        let margin = iconSize / 2 + 6
        let x = min(max(basePosition.x + offset.width, margin), canvasSize.width - margin)
        let y = min(max(basePosition.y + offset.height, margin), canvasSize.height - margin)
        return CGSize(width: x - basePosition.x, height: y - basePosition.y)
    }

    private func icon(for card: Card, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(card.backgroundColor.opacity(0.30))

            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 8, height: size - 8)
                    .clipShape(Circle())
            } else {
                Text(String(card.artistName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .medium, design: .rounded))
                    .foregroundStyle(AppStyle.ink.opacity(0.72))
            }
        }
        .frame(width: size, height: size)
        .glassEffect(.regular.tint(card.backgroundColor.opacity(0.15)).interactive(), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.68), lineWidth: 1))
        .shadow(color: card.backgroundColor.opacity(0.18), radius: 14, y: 8)
    }
}

private struct OshiCardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cards: [Card]
    @Binding var selectedArtistID: UUID?
    @Binding var selectedTab: Int

    let cardID: UUID
    @State private var showEditSheet = false

    private var card: Card? {
        cards.first(where: { $0.id == cardID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let card {
                    CardView(
                        card: card,
                        onDelete: {
                            cards.removeAll { $0.id == cardID }
                            dismiss()
                        },
                        onEdit: { showEditSheet = true },
                        onOpenCalendar: {
                            selectedArtistID = cardID
                            selectedTab = 1
                            dismiss()
                        }
                    )
                }
            }
            .navigationTitle(card?.artistName ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let card {
                    AddCardSheet(
                        onSave: { updatedCard in
                            if let index = cards.firstIndex(where: { $0.id == cardID }) {
                                cards[index] = updatedCard
                            }
                        },
                        editingCard: card
                    )
                    .presentationDetents([.large])
                }
            }
        }
    }
}

struct ContentView: View {
    @Binding var cards: [Card]
    @Binding var selectedArtistID: UUID?
    @Binding var selectedTab: Int

    @State private var showAddSheet = false
    @State private var selectedCardID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    header

                    if cards.isEmpty {
                        AddCardView(action: addCard)
                    } else {
                        OshiIconCloud(cards: cards) { card in
                            selectedCardID = card.id
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                AddCardSheet(onSave: save)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: detailSheetPresented) {
                if let selectedCardID {
                    OshiCardDetailSheet(
                        cards: $cards,
                        selectedArtistID: $selectedArtistID,
                        selectedTab: $selectedTab,
                        cardID: selectedCardID
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private var detailSheetPresented: Binding<Bool> {
        Binding(
            get: { selectedCardID != nil },
            set: { isPresented in
                if !isPresented { selectedCardID = nil }
            }
        )
    }

    private var header: some View {
        HStack {
            Text("MY OSHI")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(AppStyle.ink)

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
        .padding(.vertical, 6)
    }

    private func addCard() {
        showAddSheet = true
    }

    private func save(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        } else {
            cards.append(card)
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
