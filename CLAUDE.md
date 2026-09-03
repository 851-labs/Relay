# Relay — working notes for Claude

- Commit and push every change to `origin/main` (github.com/851-labs/relay) as soon as it's made. Don't batch or wait to be asked.
- Bundle ID is `so.alexandru.relay`. Build with `xcodegen generate` then `xcodebuild -scheme Relay -configuration Release -derivedDataPath build ENABLE_DEBUG_DYLIB=NO build`; install by copying to `/Applications/Relay.app` and relaunching (Relay reindexes Spotlight on launch).
- `build/` and `*.xcodeproj` are gitignored; `project.yml` is the source of truth.
- Anything reachable from `AppEntity` getters or `EntityQuery` methods runs on multiple threads concurrently during indexing — keep it thread-safe.
- Runtime diagnostics go to `~/Library/Logs/Relay.log` via `RelayLog.write`.
