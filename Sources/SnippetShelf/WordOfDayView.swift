import SwiftUI
import SnippetCore

struct WordListView: View {
    @EnvironmentObject private var words: WordStore
    let query: String
    @State private var pendingReuse: WordEntry?

    private func matches(_ entry: WordEntry) -> Bool {
        entry.matches(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            if words.loadState == .idle || words.loadState == .loading {
                ProgressView("Loading words…").padding()
            }
            if let error = words.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).foregroundStyle(.red)
                    Button("Retry Loading Words") { Task { await words.reload() } }
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
            }
            List(selection: $words.selectedID) {
                Section("Current word") {
                    if let current = words.current {
                        if matches(current) { row(current).tag(current.id) }
                    } else {
                        Text("No current word").foregroundStyle(.secondary)
                        Button("Add Word…") { words.draft = WordDraft(entry: nil) }.disabled(!words.canEdit)
                    }
                }
                Section("History") {
                    ForEach(words.history.filter(matches)) { entry in
                        row(entry).tag(entry.id)
                    }
                    if words.history.isEmpty {
                        Text("Previous words appear here when you add a new word.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if !query.isEmpty && !words.library.entries.contains(where: matches) {
                    Text("No matching words").foregroundStyle(.secondary).padding()
                }
            }
        }
        .modifier(ReuseWordConfirmation(entry: $pendingReuse))
    }

    private func row(_ entry: WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.word).font(.headline).lineLimit(1)
            Text(entry.definition).foregroundStyle(.secondary).lineLimit(2)
            Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button("Copy Word") { words.copy(entry) }
            Button("Edit…") { words.draft = WordDraft(entry: entry) }.disabled(!words.canEdit)
            if entry.id != words.library.currentID {
                Button("Use as Current…") { pendingReuse = entry }.disabled(!words.canEdit)
            }
        }
    }
}

struct WordDetailView: View {
    @EnvironmentObject private var words: WordStore
    @State private var pendingDelete: WordEntry?
    @State private var pendingReuse: WordEntry?

    private var selected: WordEntry? {
        words.library.entries.first { $0.id == words.selectedID }
    }

    var body: some View {
        Group {
            if let entry = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(entry.id == words.library.currentID ? "Current word" : "Past word")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(entry.word).font(.largeTitle.bold()).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(entry.definition).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Added \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                        if entry.updatedAt != entry.createdAt {
                            Text("Edited \(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                copyButton(entry)
                                editButton(entry)
                                reuseButton(entry)
                                deleteButton(entry)
                            }.fixedSize()
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    copyButton(entry)
                                    editButton(entry)
                                    Spacer(minLength: 0)
                                    deleteButton(entry)
                                }
                                reuseButton(entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "character.book.closed").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text(words.current == nil ? "Add your word of the day" : "Select a word")
                        .font(.title2.bold())
                    Text("Keep one current word and revisit past words in History.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button(words.current == nil ? "Add Word…" : "New Word…") {
                        words.draft = WordDraft(entry: nil)
                    }.disabled(!words.canEdit)
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .modifier(ReuseWordConfirmation(entry: $pendingReuse))
        .alert("Delete this word?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let entry = pendingDelete { Task { await words.delete(entry) } }
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete?.id == words.library.currentID
                 ? "This removes the current word from the menu bar. Past words will be kept."
                 : "This permanently removes the word and its definition from history.")
        }
    }

    private func copyButton(_ entry: WordEntry) -> some View {
        Button("Copy Word") { words.copy(entry) }
    }

    private func editButton(_ entry: WordEntry) -> some View {
        Button("Edit…") { words.draft = WordDraft(entry: entry) }.disabled(!words.canEdit)
    }

    @ViewBuilder
    private func reuseButton(_ entry: WordEntry) -> some View {
        if entry.id != words.library.currentID {
            Button("Use as Current…") { pendingReuse = entry }.disabled(!words.canEdit)
        }
    }

    private func deleteButton(_ entry: WordEntry) -> some View {
        Button("Delete…", role: .destructive) { pendingDelete = entry }.disabled(!words.canEdit)
    }

}

struct WordEditor: View {
    @EnvironmentObject private var words: WordStore
    @Environment(\.dismiss) private var dismiss
    let entry: WordEntry?
    @State private var word: String
    @State private var definition: String
    @State private var saveFailed = false
    @State private var saving = false

    init(entry: WordEntry?) {
        self.entry = entry
        _word = State(initialValue: entry?.word ?? "")
        _definition = State(initialValue: entry?.definition ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry == nil ? "New Word" : "Edit Word").font(.title2.bold())
            if entry == nil && words.current != nil {
                Text("Your current word will move to History when you save.").foregroundStyle(.secondary)
            } else if entry != nil {
                Text("Changes update this entry without creating a history item.").foregroundStyle(.secondary)
            }
            TextField("Word", text: $word).textFieldStyle(.roundedBorder).accessibilityLabel("Word")
            Text("Definition").font(.headline)
            TextEditor(text: $definition).font(.body)
                .border(Color.secondary.opacity(0.25)).accessibilityLabel("Definition")
            if saveFailed, let error = words.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Word") {
                    saving = true
                    Task {
                        defer { saving = false }
                        if await words.save(entry: entry, word: word, definition: definition) { dismiss() }
                        else { saveFailed = true }
                    }
                }.keyboardShortcut(.defaultAction)
                    .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !words.canEdit)
            }
        }.padding(24).frame(width: 500, height: 400)
            .disabled(saving).interactiveDismissDisabled(saving)
    }
}

// Both entry points share the same confirmation and preserve cancellation.
private struct ReuseWordConfirmation: ViewModifier {
    @EnvironmentObject private var words: WordStore
    @Binding var entry: WordEntry?

    func body(content: Content) -> some View {
        content.alert("Use ‘\(entry?.word ?? "this word")’ as your current word?", isPresented: Binding(
            get: { entry != nil }, set: { if !$0 { entry = nil } }
        )) {
            Button("Cancel", role: .cancel) { entry = nil }
            Button("Use as Current") {
                if let entry { Task { await words.reuse(entry) } }
                entry = nil
            }
        } message: {
            Text("This creates a new entry dated today and keeps the original in History."
                 + (words.current == nil ? "" : " Your current word will also move to History."))
        }
    }
}
