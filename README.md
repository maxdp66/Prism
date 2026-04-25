# Prism

<div align="center">

*APrivacy emerges gradually. Clarity is the catalyst.*

**A refined, privacy-focused web browser built for those who value both elegance and autonomy.**

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Contributing](#contributing) • [License](#license)

</div>

---

## 📖 Table of Contents

- [About](#about-prism)
- [Why Prism](#why-prism)
- [Features](#features)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Filter Lists](#filter-lists)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

---

## About Prism

Prism is a meticulously crafted web browser for macOS that prioritizes **privacy**, **performance**, and **aesthetic refinement**. Built with SwiftUI and leveraging Apple's native WebKit content-blocking APIs, Prism offers a seamless browsing experience without the tracking, advertisements, or clutter that plagues modern browsers.

<div align="center">

<img src="Screenshot 2026-04-25 at 16.46.07.png" alt="Prism Browser" width="600"/>

*Clean interface. Powerful protection. Absolute control.*

</div>

---

## Why Prism

In an era of pervasive tracking and intrusive advertising, Prism stands as a testament to what browsing *should* be:

- **No telemetry** — Your browsing data stays on your device
- **Native performance** — Swift and WebKit, no Electron bloat
- **Elegant design** — Minimal chrome, maximum focus
- **Open source** — Transparent, auditable, community-driven

---

## Features

### 🛡️ Advanced Content Blocking

Prism combines multiple filter lists to create a robust protection layer against:

- **Advertisements** — Banners, pop-ups, video ads, and sponsored content
- **Trackers** — Analytics, social media pixels, fingerprinting scripts
- **Malware & phishing** — Known malicious domains automatically blocked
- **Annoyances** — Cookie notices, newsletter popups, and other interruptions

<div align="center">

| EasyList | EasyPrivacy | Fanboy's Annoyances |
|:---:|:---:|:---:|
| Industry-standard ad blocker | Blocks tracking & telemetry | Cleans up UI clutter |

</div>

### 📋 Intelligent Tab Management

- Lightning-fast tab creation and switching
- Visual tab previews for effortless navigation
- Keyboard-first workflow (⌘T new tab, ⌘W close)
- Reopen recently closed tabs (⇧⌘T)

### 📑 Bookmark & History

- Organize bookmarks into folders
- Search through browsing history instantly
- Sidebar for quick access to favorites

### ⚙️ Flexible Settings

- Enable or disable individual filter lists
- Custom block list URLs
- Sync frequency configuration
- Clear browsing data with a single click

### 🎯 Privacy Shield

Visual indicators show active protection status at a glance.

### 🖥️ Native macOS Experience

- Built entirely with SwiftUI
- System-native shortcuts and gestures
- Metal-accelerated rendering
- Dark mode integration

---

## Installation

### Requirements

- macOS 11.0 (Big Sur) or later
- Xcode 14.0+ (for development)

### Downloading Prism

#### Option A: Releases (Recommended)

1. Visit the [Releases page](https://github.com/yourusername/prism/releases)
2. Download `Prism.dmg`
3. Drag Prism to your Applications folder
4. Launch from Applications or Spotlight

#### Option B: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/prism.git
cd Prism

# Open in Xcode
open Prism.xcodeproj
```

3. Select the `Prism` scheme and build (⌘B)
4. Run (⌘R) or export an app bundle

**Note:** First-time builds may take several minutes to resolve dependencies and compile Swift packages.

---

## Getting Started

### First Launch

When you first open Prism, you'll see:

1. A clean tab bar with the address field ready for input
2. Default filter lists enabled (EasyList, EasyPrivacy, Fanboy's Annoyances)
3. Automatic filter list download and compilation

### Navigating

- **Address bar:** Type or paste URLs; press ⇧⏎ to search
- **Tabs:** Click + to open new tabs; ⌘T and ⌘W for keyboard control
- **Sidebar:** ⌘B to toggle bookmarks and history
- **Settings:** ⌘, to customize behavior

---

## Usage

### Daily Browsing

Prism works as your daily driver:

- Search directly from the address bar (uses your default search engine)
- Multiple tabs with smooth switching
- Bookmarks organize with drag-and-drop folders
- History search finds anything you've visited

### Content Blocking

Filter lists update automatically every 24 hours, but you can:

- Manually sync: Settings → Filter Lists → Sync Now
- Disable specific lists for sites that break
- Add custom filter URLs
- View statistics: number of rules, last update time

### Keyboard Shortcuts

| Shortcut | Action |
|:---:|:---|
| ⌘T | New tab |
| ⌘W | Close tab |
| ⇧⌘T | Reopen closed tab |
| ⌘R | Reload current tab |
| ⌘B | Toggle sidebar |
| ⌘⇧B | Show bookmarks |
| ⌘← → | Switch tabs |
| ⌘, | Settings |

---

## Filter Lists

Prism supports standard AdBlock-compatible filter lists.

### Built-in Lists

| Name | Description | Enabled |
|:---|:---|:---:|
| EasyList | Primary ad blocker | ✅ |
| EasyPrivacy | Blocks trackers & analytics | ✅ |
| Fanboy's Annoyances | Removes popups & distractions | ✅ |
| EasyList Cookie List | Removes cookie notices | ❌ |
| Fanboy's Social | Blocks social widgets | ❌ |
| I Don't Care About Cookies | Auto-accepts cookies | ❌ |

### Adding Custom Lists

In Settings → Filter Lists → Add List:

1. Enter a name
2. Paste the filter list URL
3. Choose whether to enable immediately
4. Tap Add

Prism downloads, parses, and compiles the list automatically.

### Creating Your Own

Prism's adblock generator (`adblock-generator/`) converts standard filter syntax into Safari Web Extensions format.

See [adblock-generator/README.md](adblock-generator/) for details.

---

## Architecture

<div align="center">

```
┌──────────────────────────────────────────────────────────┐
│                      Prism Architecture                  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐       ┌─────────────┐                    │
│  │ SwiftUI  │◄─────►│ BrowserState│◄─────┐             │
│  └──────────┘       └─────────────┘      │             │
│           │                               │             │
│           ▼                               ▼             │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │   PrismApp        │         │   FilterList     │    │
│  │   (Entry Point)   │         │   Manager        │    │
│  └──────────────────┘         └──────────────────┘    │
│           │                               │            │
│           ▼                               ▼            │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │ ContentView      │         │ ContentBlocker   │    │
│  │ TabBarView       │◄───────►│ (WKContentRule)  │    │
│  │ AddressBarView   │         │                  │    │
│  │ SidebarView      │         └──────────────────┘    │
│  └──────────────────┘                   │            │
│           │                             │            │
│           ▼                             ▼            │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │ WKWebView        │         │ FilterLists.json │    │
│  │ (Web Content)    │         │ (Local Storage)  │    │
│  └──────────────────┘         └──────────────────┘    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

</div>

### Core Components

- **PrismApp** — Application entry points and window configuration
- **BrowserState** — Manages tabbed browsing lifecycle
- **FilterListManager** — Downloads, parses, and caches filter lists
- **ContentBlocker** — Compiles filter rules into WKContentRuleList and injects into web views
- **FilterList** — Model representing a single filter list (id, URL, enabled state, rule count)
- **BookmarkStore** — Persistent bookmark and history storage

### Filter Processing Pipeline

```
Filter URL 
    ↓
HTTP GET (async download)
    ↓
UTF-8 decode
    ↓
Line-by-line parsing (skip comments & empty lines)
    ↓
Count valid rules
    ↓
Convert to WKContentRuleList JSON
    ↓
WKContentRuleListStore.compileContentRuleList()
    ↓
WKWebView configuration.contentRuleList = compiledList
```

---

## Contributing

Prism is open source and welcomes contributions of all kinds — from bug reports and feature suggestions to code contributions and documentation improvements.

<div align="center">

```
            🎯 Contribution Workflow 🎯
```

</div>

1. **Fork the repository**
2. **Create a branch** (`git checkout -b feature/your-feature-name`)
3. **Write clean, documented code** following Swift API Design Guidelines
4. **Test thoroughly** on your local machine
5. **Commit with descriptive messages** (`git commit -m "feat: add custom filter list import"`)
6. **Push to your fork** (`git push origin feature/your-feature-name`)
7. **Open a Pull Request** with a clear description

### Development Guidelines

- Use **SwiftLint** to maintain consistent style (config provided)
- Write **unit tests** for new logic (XCTest)
- Document **public APIs** with Swift-DocC comments
- Keep UI work **adaptive** (support various window sizes)
- Update **README.md** if user-facing changes occur

### Areas Needing Help

- [ ] Performance optimization (startup time, memory footprint)
- [ ] Additional filter list parser edge cases
- [ ] Internationalization (i18n)
- [ ] Accessibility (VoiceOver, keyboard navigation)
- [ ] Automated UI tests

We appreciate every contribution, no matter the size.

---

## Code of Conduct

Prism adheres to the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold this code. Please report unacceptable behavior to the project maintainers.

---

## License

Prism is released under the MIT License. See [LICENSE](LICENSE) for full text.

```
MIT License

Copyright (c) 2024 Prism Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

<div align="center">

---

**Prism** — *Where clarity meets privacy.*

[⬆ Back to top](#prism)

</div>
