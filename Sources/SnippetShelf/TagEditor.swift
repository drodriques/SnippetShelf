import SwiftUI
import SnippetCore

struct TagEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SnippetStore
    @State var tag: SnippetTag
    @State private var saving = false
    @State private var failure: String?
    let isExisting: Bool

    private var availableParents: [SnippetTag] {
        let excluded = store.library.subtreeIDs(of: tag.id)
        return store.index.tagsByPath.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isExisting ? "Rename or Move Tag" : "New Tag").font(.title2.bold())
            TextField("Tag name", text: $tag.name).textFieldStyle(.roundedBorder)
            Picker("Parent", selection: $tag.parentID) {
                Text("Top Level").tag(nil as UUID?)
                ForEach(availableParents) { parent in
                    Text(store.tagPath(for: parent.id)).tag(Optional(parent.id))
                }
            }
            Text("Choose a parent to nest this tag. Snippets keep their assignments when a tag moves.")
                .foregroundStyle(.secondary).font(.callout)
            if let failure { Text(failure).foregroundStyle(.red).font(.caption) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Tag") {
                    saving = true
                    Task {
                        defer { saving = false }
                        if await store.saveTag(tag) {
                            store.scope = .tag(tag.id)
                            dismiss()
                        } else {
                            failure = store.errorMessage ?? "The tag could not be saved."
                        }
                    }
                }.keyboardShortcut(.defaultAction)
                    .disabled(tag.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 440)
            .disabled(saving).interactiveDismissDisabled(saving)
    }
}
