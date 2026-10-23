import SwiftUI
import SnippetCore

struct SnippetDetailView: View {
    @EnvironmentObject private var store: SnippetStore
    let snippet: Snippet
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(snippet.title).font(.largeTitle.bold()).textSelection(.enabled)
                Spacer()
                if snippet.isFavorite { Image(systemName: "star.fill").foregroundStyle(.orange) }
            }
            if !snippet.tagIDs.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(store.index.tagsByPath.filter { snippet.tagIDs.contains($0.id) }) { tag in
                            Button { store.scope = .tag(tag.id) } label: {
                                Label(store.tagPath(for: tag.id), systemImage: "tag")
                            }.buttonStyle(.bordered).font(.caption)
                        }
                    }
                }.snippetScrollbars()
            }
            ScrollView {
                Text(snippet.content).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.snippetScrollbars().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button { store.copy(snippet) } label: { Label("Copy Snippet", systemImage: "doc.on.doc") }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Edit…", action: onEdit)
                Spacer()
                Button("Delete…", role: .destructive, action: onDelete)
            }
            Text("Updated \(snippet.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }
}
