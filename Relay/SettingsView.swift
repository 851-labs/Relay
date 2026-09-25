import ServiceManagement
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

    /// General stays visible while searching only if the query matches it or one of its settings.
    private var showsGeneral: Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || GeneralSettingsView.searchTerms.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedBundleID) {
                if showsGeneral {
                    Section {
                        Label("General", systemImage: "gear")
                            .tag(GeneralSettingsView.selectionID)
                    }
                }
                Section {
                    ForEach(visibleApps) { app in
                        Label {
                            Text(app.name)
                        } icon: {
                            AppIcon(bundleID: app.bundleID, size: 20)
                        }
                        .tag(app.bundleID)
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
            .focused($sidebarFocused)
            .navigationSplitViewColumnWidth(220)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                if selectedBundleID == GeneralSettingsView.selectionID {
                    GeneralSettingsView()
                } else if let app = store.apps.first(where: { $0.bundleID == selectedBundleID }) {
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
            if selectedBundleID == nil { selectedBundleID = GeneralSettingsView.selectionID }
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

private struct GeneralSettingsView: View {
    /// Sidebar selection value for this pane; can't collide with a bundle ID since those are reverse-DNS.
    static let selectionID = "general"
    static let searchTerms = ["General", "Open at Login", "Launch at Login", "Startup"]

    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: Binding(
                    get: { opensAtLogin },
                    set: { setOpensAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .navigationTitle("General")
        // The user can also change this in System Settings › General › Login Items.
        .onAppear { opensAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            RelayLog.write("failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

private struct AppDetailView: View {
    let app: RelayedApp
    private let store = CommandStore.shared

    private var appIsEnabled: Bool { store.isAppEnabled(app.bundleID) }

    private var appEnabled: Binding<Bool> {
        Binding(
            get: { store.isAppEnabled(app.bundleID) },
            // Animate from the mutation so the section's opacity and disabled state transition together;
            // an `.animation(value:)` on the Section doesn't reach into individual list rows.
            set: { enabled in withAnimation(.default) { store.setAppEnabled(enabled, bundleID: app.bundleID) } }
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
                    HStack {
                        Label {
                            Text(command.title)
                        } icon: {
                            AppIcon(bundleID: command.bundleID, size: 20)
                        }
                        .opacity(appIsEnabled ? 1 : 0.4)

                        Spacer()

                        // Always available, even for disabled commands, so users can see what a command does before exposing it.
                        Button {
                            RelayLog.write("running \(command.id) from settings")
                            CommandRunner.run(command)
                        } label: {
                            Label("Run", systemImage: "play.circle")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Run \(command.title) now")

                        Toggle(command.title, isOn: Binding(
                            get: { store.isEnabled(command) },
                            set: { store.setEnabled($0, for: command) }
                        ))
                        .labelsHidden()
                        // Native disabled switch while the app is off, with per-command state kept for when it comes back.
                        // Scoped to the switch so the Run button stays usable.
                        .disabled(!appIsEnabled)
                    }
                }
            } header: {
                Text("Commands")
                    .opacity(appIsEnabled ? 1 : 0.4)
            }
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
