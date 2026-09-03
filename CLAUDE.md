# Relay — working notes for Claude

- Commit and push every change to `origin/main` (github.com/851-labs/relay) as soon as it's made. Don't batch or wait to be asked.
- Bundle ID is `so.alexandru.relay`. Build with `xcodegen generate` then `xcodebuild -scheme Relay -configuration Release -derivedDataPath build build`; install by copying to `/Applications/Relay.app` and relaunching (Relay reindexes Spotlight on launch).
- `build/` and `*.xcodeproj` are gitignored; `project.yml` is the source of truth.
- Anything reachable from `AppEntity` getters or `EntityQuery` methods runs on multiple threads concurrently during indexing — keep it thread-safe.
- Runtime diagnostics go to `~/Library/Logs/Relay.log` via `RelayLog.write`.
- Swift 6 language mode with approachable concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`). Types handed to App Intents (`Command`, `CommandQuery`, `IconCache`, `RelayLog`) are `nonisolated`; intents use a `nonisolated` conformance (`struct X: nonisolated AppIntent`) because type-level `nonisolated` can't apply to `@Parameter` storage. Shared mutable state uses `Mutex` from Synchronization, never `nonisolated(unsafe)` or `@unchecked Sendable`.
