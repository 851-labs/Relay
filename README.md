# Relay

A macOS menu-bar app that exposes third-party app commands (CleanShot X, etc.) to Spotlight via App Intents.

Each command is an `AppEntity` indexed into Spotlight with the target app's icon; selecting it fires a URL scheme or shell command.

## Build

```sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme Relay -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Relay.app /Applications/
open /Applications/Relay.app
```

## Commands

Edit `Relay/Resources/commands.json` (or `~/Library/Application Support/Relay/commands.json` to override). Relay reindexes Spotlight on launch.
