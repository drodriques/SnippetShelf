import SwiftUI

/// Owns expansion, focus and animation; its parent supplies only query and width.
struct LibrarySearchHeader: View {
    let title: String
    let width: CGFloat
    @Binding var query: String
    @Binding var requestsFocus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchExpanded = false
    @State private var searchHasFocus = false
    private var searchFieldWidth: CGFloat { min(200, max(120, width - 150)) }

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            searchControl
                .frame(width: searchFieldWidth, alignment: .trailing)
        }
        .padding(.leading, 12)
        .frame(width: width)
        .onChange(of: requestsFocus) { if $0 { searchExpanded = true } }
    }

    private let searchControlHeight: CGFloat = 36

    private var searchControl: some View {
        HStack(spacing: 6) {
            if searchExpanded {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                ToolbarSearchTextField(text: $query, requestsFocus: $requestsFocus,
                    onFocusChange: { focused in
                        searchHasFocus = focused
                        if !focused {
                            DispatchQueue.main.async {
                                if !searchHasFocus && !requestsFocus && query.isEmpty {
                                    searchExpanded = false
                                }
                            }
                        }
                    }, onEscape: {
                        if query.isEmpty {
                            searchExpanded = false
                            searchHasFocus = false
                        } else {
                            requestsFocus = true
                            query = ""
                        }
                    })
                    .frame(height: 18)
                if !query.isEmpty {
                    Button { requestsFocus = true; query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            } else {
                Button { openSearch() } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search this group")
                .help("Search this group (⌘F)")
            }
        }
        .padding(.horizontal, searchExpanded ? 10 : 8)
        .frame(width: searchExpanded ? searchFieldWidth : searchControlHeight, height: searchControlHeight)
        .overlay(RoundedRectangle(cornerRadius: searchExpanded ? 7 : searchControlHeight / 2)
            .strokeBorder(searchHasFocus ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.12)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: searchExpanded)
    }

    private func openSearch() {
        searchExpanded = true
        requestsFocus = true
    }
}
