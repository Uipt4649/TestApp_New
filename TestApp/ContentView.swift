//
//  ContentView.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2025/12/21.
//
import SwiftUI
import PhotosUI

// MARK: - Card Model
struct Card: Identifiable, Equatable {
    let id = UUID()
    var artistName: String
    var image: UIImage?
    var description: String?
    var backgroundColor: Color
}

// MARK: - Card View
struct CardView: View {
    let card: Card
    let geo: GeometryProxy
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        GeometryReader { cardGeo in
            let screenCenterX = geo.size.width / 2
            let cardCenterX = cardGeo.frame(in: .global).midX
            let distance = cardCenterX - screenCenterX
            let progress = distance / geo.size.width
            let angle = -Double(progress) * 30

            ZStack(alignment: .topTrailing) {
                card.backgroundColor

                VStack(spacing: 16) {
                    if let image = card.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.45)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.45)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }

                    Text(card.artistName)
                        .font(.title)
                        .bold()
                        .padding(.horizontal)

                    if let description = card.description {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(description)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .frame(height: geo.size.height * 0.2)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    Spacer()

                    Button {
                        // TODO: カレンダー遷移
                    } label: {
                        Label("カレンダーを開く", systemImage: "calendar")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.95)

                HStack(spacing: 16) {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }

                    Button { showDeleteAlert = true } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    .alert("このカードを削除しますか？", isPresented: $showDeleteAlert) {
                        Button("削除", role: .destructive) { onDelete() }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
                .padding()
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        }
        .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.95)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 5)
    }
}

// MARK: - Add Card View
struct AddCardView: View {
    let geo: GeometryProxy
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Color.gray.opacity(0.15)
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                    Text("カードを追加")
                }
                .foregroundColor(.secondary)
            }
            .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.95)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 5)
        }
    }
}

// MARK: - Add/Edit Card Sheet
struct AddCardSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var artistName = ""
    @State private var description = ""
    @State private var backgroundColor: Color = .blue
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?

    let onAdd: (Card) -> Void
    var editingCard: Card? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("アーティスト名（必須）") { TextField("名前を入力", text: $artistName) }
                Section("画像") {
                    PhotosPicker(selection: $selectedItem, matching: .images) { Text("画像を選択") }
                    if let image { Image(uiImage: image).resizable().scaledToFit().frame(height: 150) }
                }
                Section("説明（任意）") { TextEditor(text: $description).frame(height: 100) }
                Section("背景色") { ColorPicker("選択", selection: $backgroundColor) }
            }
            .navigationTitle(editingCard == nil ? "カードを追加" : "カードを編集")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingCard == nil ? "追加" : "保存") {
                        let newCard = Card(
                            artistName: artistName,
                            image: image,
                            description: description.isEmpty ? nil : description,
                            backgroundColor: backgroundColor
                        )
                        onAdd(newCard)
                        dismiss()
                    }
                    .disabled(artistName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            }
            .onAppear {
                if let editingCard {
                    artistName = editingCard.artistName
                    description = editingCard.description ?? ""
                    backgroundColor = editingCard.backgroundColor
                    image = editingCard.image
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) { image = uiImage }
                }
            }
        }
    }
}

// MARK: - Content View (Home)
struct ContentView: View {
    
    @Binding var cards: [Card]
    
    @State private var showAddSheet = false
    @State private var editingCard: Card? = nil
    @State private var currentIndex: Int = 0

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(Array(cards.enumerated()), id: \.1.id) { index, card in
                            CardView(card: card, geo: geo,
                                     onDelete: { cards.removeAll { $0.id == card.id } },
                                     onEdit: {
                                        editingCard = card
                                        showAddSheet = true
                                     })
                            .id(index)
                        }

                        AddCardView(geo: geo) {
                            editingCard = nil
                            showAddSheet = true
                        }
                        .id(cards.count)
                    }
                    .padding(.horizontal, (geo.size.width - geo.size.width * 0.9) / 2)
                }
                .gesture(
                    DragGesture()
                        .onEnded { _ in
                            let nearestIndex = Int(round(Double(currentIndex)))
                            let clampedIndex = min(max(nearestIndex, 0), cards.count)
                            withAnimation { scrollProxy.scrollTo(clampedIndex, anchor: .center) }
                        }
                )
            }
            .sheet(isPresented: $showAddSheet) {
                AddCardSheet(onAdd: { newCard in
                    if let editingCard {
                        if let index = cards.firstIndex(where: { $0.id == editingCard.id }) { cards[index] = newCard }
                    } else { cards.append(newCard) }
                }, editingCard: editingCard)
            }
        }
    }
}

// MARK: - Tab View
struct SelectView: View {
    
    @State private var events: [Event] = []
    @State private var logs: [LogEntry] = []
    @State private var cards: [Card] = []

    var body: some View {
        TabView {
            // Homeタブ
            ContentView(cards: $cards)
                .tabItem { Label("Home", systemImage: "house.fill") }

            // Calendarタブ
            CalendarView(events: $events)
                .tabItem { Label("Calendar", systemImage: "calendar") }

            // Eventタブ
            EventView(events: $events)
                .tabItem { Label("Event", systemImage: "star.circle") }

            // Logタブ
            LogView(logs: $logs)
                .tabItem { Label("Log", systemImage: "square.and.pencil") }
        }
    }
}

#Preview {
    SelectView()
}
