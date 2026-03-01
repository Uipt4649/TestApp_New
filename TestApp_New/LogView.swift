//
//  LogView.swift
//  TestApp
//
//  Created by 渡邉羽唯 on 2026/02/01.
//

import SwiftUI
import PhotosUI

// MARK: - Log Model
struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    var title: String
    var content: String
    var image: UIImage?
}

// MARK: - Log View
struct LogView: View {
    
    @Binding var logs: [LogEntry]
    
    @State private var showAddSheet = false
    @State private var editingLog: LogEntry? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "日記がありません",
                        systemImage: "book",
                        description: Text("右上の＋ボタンで日記を追加しよう")
                    )
                } else {
                    ForEach(logs.sorted(by: { $0.date > $1.date })) { log in
                        Button {
                            editingLog = log
                            showAddSheet = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(log.title)
                                        .font(.headline)
                                    Text(shortDateLabel(for: log.date))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if log.image != nil {
                                    Image(systemName: "photo")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        // Binding経由で親のデータを直接削除します
                        let sortedLogs = logs.sorted(by: { $0.date > $1.date })
                        let idsToDelete = offsets.map { sortedLogs[$0].id }
                        logs.removeAll { idsToDelete.contains($0.id) }
                    }
                }
            }
            .navigationTitle("日記")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingLog = nil
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddLogSheet(
                    log: editingLog,
                    onAdd: { newLog in
                        if let editing = editingLog,
                           let index = logs.firstIndex(where: { $0.id == editing.id }) {
                            logs[index] = newLog
                        } else {
                            logs.append(newLog)
                        }
                    }
                )
            }
        }
    }
    
    private func shortDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Add/Edit Log Sheet
struct AddLogSheet: View {
    @Environment(\.dismiss) var dismiss
    var log: LogEntry? = nil
    let onAdd: (LogEntry) -> Void
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("タイトルを入力", text: $title)
                }
                
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(height: 150)
                }
                
                Section("写真") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("写真を選択")
                    }
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle(log == nil ? "日記を追加" : "日記を編集")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(log == nil ? "追加" : "保存") {
                        let newLog = LogEntry(
                            date: log?.date ?? Date(), // 編集時は日付を維持
                            title: title,
                            content: content,
                            image: image
                        )
                        onAdd(newLog)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                if let log {
                    title = log.title
                    content = log.content
                    image = log.image
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        image = uiImage
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    
    LogView(logs: .constant([]))
}
