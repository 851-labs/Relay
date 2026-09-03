import SwiftUI

struct SettingsView: View {
    private let store = CommandStore.shared
    @State private var selectedBundleID: String?

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
            if let app = store.apps.first(where: { $0.bundleID == selectedBundleID }) {
                AppDetailView(app: app)
            } else {
                ContentUnavailableView("Select an App", systemImage: "bolt.horizontal",
                                       description: Text("Choose an app to manage the commands Relay exposes to Spotlight."))
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            if selectedBundleID == nil { selectedBundleID = store.apps.first?.bundleID }
        }
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
                ForEach(app.commands) { command in
                    Toggle(isOn: Binding(
                        get: { store.isEnabled(command) },
                        set: { store.setEnabled($0, for: command) }
                    )) {
                        Label(command.title, systemImage: command.symbol ?? "bolt.horizontal")
                    }
                }
            } header: {
                // Lives in the section header so it scrolls with the content but isn't wrapped in a card.
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 8) {
                        AppIcon(bundleID: app.bundleID, size: 96)
                        Text(app.name)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("^[\(app.commands.count) command](inflect: true)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                    Text("Commands")
                        .font(.headline)
                        .foregroundStyle(.primary)
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
