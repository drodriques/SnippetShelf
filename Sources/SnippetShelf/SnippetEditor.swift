import SwiftUI
import SnippetCore

struct SnippetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SnippetStore
    @State var snippet: Snippet
    @State private var saveFailed = false
    @State private var saving = false
    let onSave: (Snippet) async -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(snippet.title.isEmpty ? "New Snippet" : "Edit Snippet").font(.title2.bold())
            TextField("Title", text: $snippet.title).textFieldStyle(.roundedBorder)
            Text("Content").font(.headline)
            TextEditor(text: $snippet.content)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.25))
                .accessibilityLabel("Snippet content")
            Toggle("Favorite — show first in the menu", isOn: $snippet.isFavorite)
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags").font(.headline)
                if store.library.tags.isEmpty {
                    Text("Create tags using Manage Tags in the main window.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.index.tagsByPath) { tag in
                                Toggle(store.tagPath(for: tag.id), isOn: Binding(
                                    get: { snippet.tagIDs.contains(tag.id) },
                                    set: { checked in
                                        if checked { snippet.tagIDs.insert(tag.id) }
                                        else { snippet.tagIDs.remove(tag.id) }
                                    }
                                )).toggleStyle(.checkbox)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(height: 105)
                }
            }
            if saveFailed {
                Text("Could not save. Your draft is still here. Check the error in the main window.")
                    .foregroundStyle(.red).font(.caption)
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Snippet") {
                    saving = true
                    Task {
                        defer { saving = false }
                        if await onSave(snippet) { dismiss() } else { saveFailed = true }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(snippet.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || snippet.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 560, height: 590)
            .disabled(saving).interactiveDismissDisabled(saving)
    }
}
