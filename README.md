# Prism

<div align="center">

<img src="demo.png" alt="Prism Browser" width="500" style="border-radius: 12px"/>

*Privacy emerges gradually. Clarity is the catalyst.*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS%2015.0%2B-green)]()
[![Built with Swift](https://img.shields.io/badge/Built%20with-SwiftUI+WebKit-orange)]()

A native macOS web browser built with SwiftUI and WebKit. Privacy-focused, no Chromium.

</div>

---

## Features

| Feature | Description |
|---------|-------------|
| **Content blocking** | Ad, tracker, and malware blocking via compiled WKContentRuleList rules |
| **Filter list management** | Toggle built-in lists (EasyList, EasyPrivacy, Fanboy's) or add custom URLs |
| **Tab management** | Standard, Compact, and Vertical tab layouts with drag-and-drop |
| **Quick access links** | User-configurable shortcuts on the new tab page with favicon caching |
| **Search engine choice** | DuckDuckGo (default), Google, Bing, Brave, Ecosia, or self-hosted SearXNG |
| **Autocomplete** | Suggestions from DuckDuckGo, Google, or Brave Search |
| **Bookmarks & history** | Sidebar with full history search and bookmark management |
| **Privacy controls** | Toggle content blocker, JavaScript, and autoplay per-session |
| **Dark mode** | System, light, or dark appearance |

## Build from source

Requires macOS 15.0+ and Xcode 16.0+.

```bash
git clone https://github.com/maxdp66/Prism.git
cd Prism
open Prism.xcodeproj
```

Select the **Prism** scheme, then `Cmd+B` to build or `Cmd+R` to run.

### Adblock rules generator

The `adblock-generator/` directory contains a standalone Rust CLI that converts ABP filter lists into WebKit content-blocking JSON.

```bash
cd adblock-generator
cargo build --release
./generate_rules.sh
```

Output goes to `Prism/Resources/blockerRules.json` (30 MB, bundled). Regenerate only if filter lists change.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Shift+Cmd+T` | Reopen closed tab |
| `Cmd+B` | Toggle bookmarks sidebar |
| `Cmd+F` | Find in page |
| `Cmd+R` | Reload page |
| `Cmd+=` / `Cmd+-` | Zoom in / out |
| `Cmd+0` | Reset zoom |
| `Cmd+P` | Print |
| `Cmd+,` | Settings |

## Content blocking

Prism uses a Rust-based tool to compile AdBlock Plus filter lists into Safari's native `WKContentRuleList` format. Filter lists are downloaded, parsed, and injected into WebKit at launch, with automatic refresh every 24 hours.

Built-in lists: **EasyList** (ads), **EasyPrivacy** (trackers), **Fanboy's Annoyances** (UI clutter). Additional lists and custom URLs can be added in Settings.

## Architecture

- **`PrismApp.swift`** -- App entry point, environment injection, command menus
- **`BrowserState.swift`** -- Central `@MainActor` state managing tabs, WKWebView config, content blocker
- **`Prism/Models/`** -- Data models, persistence stores (UserDefaults), services
- **`Prism/Views/`** -- SwiftUI views (content, tabs, address bar, settings, sidebar)
- **`Prism/WebEngine/`** -- WKContentRuleList compilation and loading
- **`Prism/Utilities/`** -- URL validation, structured logging
- **`adblock-generator/`** -- Rust CLI for filter list compilation

All state classes use `@MainActor`. Persistence is via UserDefaults with async JSON encoding.

## Contributing

1. Fork the repository
2. Create a branch (`git checkout -b feature/my-feature`)
3. Commit with descriptive messages
4. Push and open a Pull Request

## License

MIT -- see [LICENSE](LICENSE) for details.
