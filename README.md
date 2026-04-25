# 🔷 Prism

<div align="center">

<img src="Screenshot 2026-04-25 at 16.46.07.png" alt="Prism Browser" width="500" style="border-radius: 12px; margin-bottom: 20px"/>

### *Privacy emerges gradually. Clarity is the catalyst.*

A refined, privacy-focused web browser built for those who value both elegance and autonomy.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS%2011.0%2B-green)]()
[![Built with Swift](https://img.shields.io/badge/Built%20with-SwiftUI-orange)]()

<br/>

**[Features](#-features) • [Installation](#-installation) • [Usage](#-keyboard-shortcuts) • [Contributing](#-contributing) • [License](#-license)**

</div>

---

---

## About Prism

Prism is a meticulously crafted web browser for macOS that prioritizes **privacy**, **performance**, and **aesthetic refinement**. Built with SwiftUI and leveraging Apple's native WebKit content-blocking APIs, Prism offers a seamless browsing experience without the tracking, advertisements, or clutter that plagues modern browsers.

> **Clean interface. Powerful protection. Absolute control.**

---

## Why Prism?

In an era of pervasive tracking and intrusive advertising, Prism stands as a testament to what browsing *should* be:

| ✨ Feature | 📝 Description |
|-----------|---|
| **No telemetry** | Your browsing data stays on your device |
| **Native performance** | Swift and WebKit, no Electron bloat |
| **Elegant design** | Minimal chrome, maximum focus |
| **Open source** | Transparent, auditable, community-driven |

---

## 🌟 Features

### 🛡️ Advanced Content Blocking

Prism combines multiple filter lists to create a robust protection layer:

- **Advertisements** — Banners, pop-ups, video ads, sponsored content
- **Trackers** — Analytics, social media pixels, fingerprinting scripts
- **Malware & Phishing** — Known malicious domains automatically blocked
- **Annoyances** — Cookie notices, newsletter popups, UI clutter

**Popular Filter Lists:**
- ✅ **EasyList** — Industry-standard ad blocker
- ✅ **EasyPrivacy** — Blocks tracking & telemetry
- ✅ **Fanboy's Annoyances** — Cleans up UI clutter
- ⚪ **EasyList Cookie List** — Removes cookie notices (optional)
- ⚪ **Fanboy's Social** — Blocks social widgets (optional)

### 📋 Intelligent Tab Management

- ⚡ Lightning-fast tab creation and switching
- 👁️ Visual tab previews for effortless navigation
- ⌨️ Keyboard-first workflow (`⌘T` new tab, `⌘W` close)
- 🔄 Reopen recently closed tabs (`⇧⌘T`)

### 📑 Bookmark & History Management

- 📂 Organize bookmarks into folders
- 🔍 Search through browsing history instantly
- ⭐ Sidebar for quick access to favorites
- ☁️ Automatic sync with local storage

### ⚙️ Flexible Settings

- Enable or disable individual filter lists
- Custom block list URLs
- Sync frequency configuration
- Clear browsing data with one click
- Dark mode integration

### 🎯 Privacy Shield

Visual indicators show active protection status at a glance, so you always know you're protected.

### 🖥️ Native macOS Experience

- Built entirely with **SwiftUI**
- System-native shortcuts and gestures
- Metal-accelerated rendering
- Full Dark Mode support
- Adaptive window sizing

---

## 🚀 Installation

### System Requirements

- **macOS** 11.0 (Big Sur) or later
- **Xcode** 14.0+ (for development only)

### Option A: Download Binary (Recommended)

1. Visit the [Releases page](https://github.com/yourusername/prism/releases)
2. Download `Prism.dmg`
3. Drag **Prism** to your **Applications** folder
4. Launch from Applications or Spotlight

### Option B: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/prism.git
cd Prism

# Open in Xcode
open Prism.xcodeproj
```

3. Select the `Prism` scheme
4. Build with `⌘B`
5. Run with `⌘R` or export an app bundle

> **Tip:** First-time builds may take several minutes to resolve dependencies.

---

## 📱 Getting Started

### First Launch

When you first open Prism:

✅ Clean tab bar ready for input
✅ Default filter lists enabled (EasyList, EasyPrivacy, Fanboy's Annoyances)
✅ Automatic filter list download and compilation

### Quick Navigation Guide

| Action | Shortcut |
|--------|----------|
| **Type a URL** | Click address bar or start typing |
| **Search the web** | Type in address bar + `⇧⏎` |
| **Open new tab** | `⌘T` |
| **Close tab** | `⌘W` |
| **Switch tabs** | `⌘←` / `⌘→` |
| **Toggle sidebar** | `⌘B` |
| **Settings** | `⌘,` |
| **Reload page** | `⌘R` |

---

## ⌨️ Keyboard Shortcuts

Master Prism with these keyboard shortcuts:

```
Navigation
  ⌘T             New tab
  ⌘W             Close tab
  ⇧⌘T            Reopen closed tab
  ⌘R             Reload page
  ⌘L             Focus address bar
  
Browsing
  ⌘B             Toggle sidebar
  ⌘⇧B            Show bookmarks
  ⌘←   →         Switch between tabs
  ⌘↑   ↓         Switch between windows
  
Application
  ⌘,             Open Settings
  ⌘Q             Quit Prism
  ⌘H             Hide Prism
  ⌘M             Minimize window
```

---

## 🔧 Content Blocking

### How It Works

1. **Download** filter lists from configured URLs
2. **Parse** rules in AdBlock syntax
3. **Compile** into Safari-compatible `WKContentRuleList` format
4. **Inject** into WebView for all pages
5. **Refresh** automatically every 24 hours

### Managing Filter Lists

#### Enable/Disable Built-in Lists

Go to **Settings → Filter Lists** to toggle:
- EasyList
- EasyPrivacy
- Fanboy's Annoyances
- And more optional lists

#### Add Custom Block Lists

1. Open **Settings → Filter Lists → Add List**
2. Enter a name and filter list URL
3. Click **Add**
4. Prism downloads and compiles automatically

#### Manual Sync

Need an immediate update? Click **Sync Now** in Settings → Filter Lists

#### Filter List Details

| Name | Type | Purpose | Enabled |
|------|------|---------|---------|
| EasyList | Ads | Primary ad blocker | ✅ |
| EasyPrivacy | Trackers | Tracking prevention | ✅ |
| Fanboy's Annoyances | UI | Pop-ups & clutter | ✅ |
| Cookie Notice List | Privacy | Cookie notices | ⚪ |
| Fanboy's Social | Social | Social widgets | ⚪ |
| I Don't Care About Cookies | Privacy | Auto-accept cookies | ⚪ |

### Creating Custom Filter Lists

See [adblock-generator/README.md](adblock-generator/) to create your own filter lists.

---

## 🏗️ Architecture

### Component Overview

```
Prism Browser Architecture
├── Presentation Layer
│   ├── PrismApp (Entry point)
│   └── Views/
│       ├── ContentView
│       ├── TabBarView
│       ├── AddressBarView
│       ├── SidebarView
│       ├── SettingsView
│       └── WebContentView
│
├── State Management
│   ├── BrowserState (Tab lifecycle)
│   └── FilterListManager (Filter rules)
│
├── Content Blocking
│   ├── ContentBlocker (Rule compilation)
│   ├── FilterList (List metadata)
│   └── FilterListManager (List management)
│
├── Data Layer
│   ├── HistoryStore
│   ├── BookmarkStore
│   └── blockerRules.json
│
└── Web Engine
    ├── WKWebView (WebKit rendering)
    ├── WKContentRuleListStore (Rule compilation)
    └── WKContentRuleList (Compiled rules)
```

### Data Flow

```
User Input
    ↓
BrowserState (manages tabs/history)
    ↓
FilterListManager (downloads & parses rules)
    ↓
ContentBlocker (compiles to WKContentRuleList)
    ↓
WKWebView (injects rules before page load)
    ↓
Blocks ads, trackers, malware
    ↓
User sees clean, private web page
```

---

## 🤝 Contributing

We welcome contributions of all kinds! Whether it's bug reports, feature requests, or code contributions, your help makes Prism better.

### How to Contribute

1. **Fork** the repository
2. **Create a branch** (`git checkout -b feature/amazing-feature`)
3. **Code** with care and clarity
4. **Write tests** for new functionality
5. **Commit** with descriptive messages
6. **Push** to your fork
7. **Open a Pull Request** with details

### Development Guidelines

- ✅ Follow Swift API Design Guidelines
- ✅ Use SwiftLint for consistent style
- ✅ Write unit tests (XCTest)
- ✅ Document public APIs with Swift-DocC
- ✅ Support various window sizes
- ✅ Update README for user-facing changes

### Areas Needing Help

- 🚀 Performance optimization (startup time, memory)
- 🛡️ Filter list parsing edge cases
- 🌍 Internationalization (i18n)
- ♿ Accessibility (VoiceOver, keyboard navigation)
- 🧪 Automated UI tests
- 📚 Documentation improvements

---

## 📋 Code of Conduct

Prism adheres to the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). We are committed to providing a welcoming and inspiring community for all. Please report unacceptable behavior to the project maintainers.

---

## 📄 License

Prism is released under the **MIT License**.

```
MIT License

Copyright (c) 2024 Prism Contributors

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions...
```

See [LICENSE](LICENSE) for the full text.

---

<div align="center">

### 🔷 Prism

**Where clarity meets privacy.**

[⬆ Back to top](#prism)

</div>
