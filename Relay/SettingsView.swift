import SwiftUI

struct SettingsView: View {
    private let store = CommandStore.shared
    @State private var selectedBundleID: String?
    @State private var history = SelectionHistory()
    @FocusState private var sidebarFocused: Bool
    @State private var searchText = ""
    /// Pinned to `.all`; the sidebar is never collapsible (System Settings keeps its sidebar fixed).
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Apps whose name, or any command title/keyword, matches the search — like System Settings matching pane contents.
    private var visibleApps: [RelayedApp] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.apps }
        return store.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) || app.commands.contains { $0.matches(query) }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(visibleApps, selection: $selectedBundleID) { app in
                Label {
                    Text(app.name)
                } icon: {
                    AppIcon(bundleID: app.bundleID, size: 20)
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
            .focused($sidebarFocused)
            .navigationSplitViewColumnWidth(220)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                if let app = store.apps.first(where: { $0.bundleID == selectedBundleID }) {
                    AppDetailView(app: app)
                } else {
                    ContentUnavailableView("Select an App", systemImage: "bolt.horizontal",
                                           description: Text("Choose an app to manage the commands Relay exposes to Spotlight."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    // The native back/forward control (System Settings, Xcode): AppKit draws the
                    // grouped capsule, divider, sizing, and disabled dimming.
                    ControlGroup {
                        Button { navigate(by: -1) } label: { Label("Back", systemImage: "chevron.left") }
                            .disabled(!history.canGoBack)
                            .help("Back")
                            .keyboardShortcut("[", modifiers: .command)
                        Button { navigate(by: 1) } label: { Label("Forward", systemImage: "chevron.right") }
                            .disabled(!history.canGoForward)
                            .help("Forward")
                            .keyboardShortcut("]", modifiers: .command)
                    }
                    .controlGroupStyle(.navigation)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            if selectedBundleID == nil { selectedBundleID = store.apps.first?.bundleID }
            // Keep the sidebar the focused responder so its selection draws in the accent color.
            sidebarFocused = true
        }
        .onChange(of: columnVisibility) { _, visibility in
            if visibility != .all { columnVisibility = .all }
        }
        .onChange(of: selectedBundleID) { _, bundleID in
            if let bundleID { history.record(bundleID) }
        }
    }

    private func navigate(by offset: Int) {
        if let bundleID = history.step(by: offset) { selectedBundleID = bundleID }
        sidebarFocused = true
    }
}

/// Browser-style back/forward history over sidebar selection.
private struct SelectionHistory {
    private var entries: [String] = []
    private var index = -1
    /// Set when a change originates from `step(by:)` so `record` doesn't treat it as a new visit.
    private var ignoreNextRecord = false

    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < entries.count - 1 }

    mutating func record(_ id: String) {
        if ignoreNextRecord { ignoreNextRecord = false; return }
        guard entries.indices.contains(index) == false || entries[index] != id else { return }
        entries.removeSubrange((index + 1)...)
        entries.append(id)
        index = entries.count - 1
    }

    mutating func step(by offset: Int) -> String? {
        let target = index + offset
        guard entries.indices.contains(target) else { return nil }
        index = target
        ignoreNextRecord = true
        return entries[target]
    }
}

private struct AppDetailView: View {
    let app: RelayedApp
    private let store = CommandStore.shared

    private var appIsEnabled: Bool { store.isAppEnabled(app.bundleID) }

    private var appEnabled: Binding<Bool> {
        Binding(
            get: { store.isAppEnabled(app.bundleID) },
            set: { store.setAppEnabled($0, bundleID: app.bundleID) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: appEnabled) {
                    Label {
                        Text(app.name)
                        Text("Expose ^[\(app.commands.count) command](inflect: true) from \(app.name) to Spotlight.")
                            .foregroundStyle(.secondary)
                    } icon: {
                        AppIcon(bundleID: app.bundleID, size: 28)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(app.commands) { command in
                    Toggle(isOn: Binding(
                        get: { store.isEnabled(command) },
                        set: { store.setEnabled($0, for: command) }
                    )) {
                        Label {
                            Text(command.title)
                        } icon: {
                            AppIcon(bundleID: command.bundleID, size: 20)
                        }
                        .opacity(appIsEnabled ? 1 : 0.4)
                    }
                }
            } header: {
                Text("Commands")
                    .opacity(appIsEnabled ? 1 : 0.4)
            }
            // Native disabled switches while the app is off, with per-command state kept for when it comes back.
            // Text and icons dim separately since `.disabled` only restyles the controls.
            .disabled(!appIsEnabled)
            .animation(.default, value: appIsEnabled)
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .navigationTitle(app.name)
    }
}

private struct AppIcon: View {
    let bundleID: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image = IconCache.image(for: bundleID) {
                image.resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
