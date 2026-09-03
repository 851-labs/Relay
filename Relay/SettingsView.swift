import SwiftUI

struct SettingsView: View {
    private let store = CommandStore.shared
    @State private var selectedBundleID: String?
    @State private var history = SelectionHistory()

    var body: some View {
        NavigationSplitView {
            List(store.apps, selection: $selectedBundleID) { app in
                Label {
                    Text(app.name)
                } icon: {
                    AppIcon(bundleID: app.bundleID, size: 20)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
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
                // Adjacent items in one group share a single glass capsule, like System Settings' back/forward.
                ToolbarItemGroup(placement: .navigation) {
                    Button { navigate(by: -1) } label: { Label("Back", systemImage: "chevron.left") }
                        .disabled(!history.canGoBack)
                        .keyboardShortcut("[", modifiers: .command)
                    Button { navigate(by: 1) } label: { Label("Forward", systemImage: "chevron.right") }
                        .disabled(!history.canGoForward)
                        .keyboardShortcut("]", modifiers: .command)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            if selectedBundleID == nil { selectedBundleID = store.apps.first?.bundleID }
        }
        .onChange(of: selectedBundleID) { _, bundleID in
            if let bundleID { history.record(bundleID) }
        }
    }

    private func navigate(by offset: Int) {
        if let bundleID = history.step(by: offset) { selectedBundleID = bundleID }
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

    private var allEnabled: Binding<Bool> {
        Binding(
            get: { app.commands.allSatisfy(store.isEnabled) },
            set: { store.setEnabled($0, for: app.commands) }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    AppIcon(bundleID: app.bundleID, size: 56)
                    Text(app.name)
                        .font(.title2.weight(.bold))
                    Text("^[\(app.commands.count) command](inflect: true)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Commands") {
                ForEach(app.commands) { command in
                    Toggle(isOn: Binding(
                        get: { store.isEnabled(command) },
                        set: { store.setEnabled($0, for: command) }
                    )) {
                        Label(command.title, systemImage: command.symbol ?? "bolt.horizontal")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .navigationTitle(app.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle("Enable \(app.name)", isOn: allEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .help("Enable or disable all \(app.name) commands")
            }
        }
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
