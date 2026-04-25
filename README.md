# 🔷 Prism

<div align="center">

<img src="Screenshot 2026-04-25 at 16.46.07.png" alt="Prism Browser" width="500" style="border-radius: 12px; margin-bottom: 20px"/>

### *Privacy emerges gradually. Clarity is the catalyst.*

A refined, privacy-focused web browser built for those who value both elegance and autonomy.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS%2015.0%2B-green)]()
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

- **Search Engine** — Choose from DuckDuckGo (default), Google, Bing, Brave, Ecosia, or self-hosted SearXNG
- **Autocomplete** — Suggestions from DuckDuckGo, Google, or Brave Search with optional API key
- **Filter Lists** — Enable/disable individual lists and add custom block list URLs
- **Privacy Controls** — Toggle content blocker, JavaScript, and autoplay per-page
- **Appearance** — Dark mode, light mode, or system preference
- **Clear Data** — Wipe browsing data with one click

### 🎯 Privacy Shield

Visual indicators show active protection status at a glance, so you always know you're protected.

### 🖥️ Native macOS Experience

- Built entirely with **SwiftUI**
- System-native shortcuts and gestures
- Metal-accelerated rendering
- Full Dark Mode support
- Adaptive window sizing
- Dynamic theme color extraction from web pages (macOS 15+)
- Premium header vibrancy for browser chrome

---

## 🚀 Installation

### System Requirements

- **macOS** 15.0 (Sequoia) or later
- **Xcode** 16.0+ (for development only)

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
| **Open new tab** | `⌘T` |
| **Close tab** | `⌘W` |
| **Reopen closed tab** | `⇧⌘T` |
| **Toggle bookmarks sidebar** | `⌘B` |
| **Search the web** | Type in address bar + `⏎` |
| **Find in page** | `⌘F` |
| **Reload page** | `⌘R` |
| **Settings** | `⌘,` |

---

## ⌨️ Keyboard Shortcuts

Master Prism with these keyboard shortcuts:

```
Tab Management
  ⌘T             New tab
  ⌘W             Close tab
  ⇧⌘T            Reopen closed tab
  
Navigation & Browsing
  ⌘B             Toggle bookmarks sidebar
  ⌘R             Reload page
  ⌘F             Find in page
  
Zoom & Display
  ⌘=             Zoom in
  ⌘-             Zoom out
  ⌘0             Reset zoom to actual size
  
Page Actions
  ⌘P             Print page
  
Application
  ⌘,             Open Settings
  ⌘Q             Quit Prism
  ⌘H             Hide Prism
  ⌘M             Minimize window
```

---

## ⚙️ Content Blocking & Privacy

### How Content Blocking Works

1. **Download** filter lists from configured URLs
2. **Parse** rules in AdBlock Plus syntax
3. **Compile** into Safari-compatible `WKContentRuleList` format
4. **Inject** into WebView for all pages
5. **Refresh** automatically every 24 hours

### Privacy Controls

Beyond content blocking, Prism offers fine-grained privacy control:

- **Content Blocker** — Toggle rule-based blocking (default: enabled)
- **JavaScript** — Disable JavaScript globally or per-site (default: enabled)
- **Autoplay** — Prevent videos and audio from playing automatically (default: disabled)
- **Tracking** — EasyPrivacy list blocks analytics and telemetry by default

### Managing Filter Lists

#### Enable/Disable Built-in Lists

Go to **Settings → Filter Lists** to toggle:
- EasyList (ads)
- EasyPrivacy (tracking)
- Fanboy's Annoyances (UI clutter)
- Cookie notices, social widgets, and more

#### Add Custom Block Lists

1. Open **Settings → Filter Lists → Add Custom List**
2. Enter a name and filter list URL (must be in AdBlock format)
3. Prism downloads and compiles automatically
4. Toggle on/off anytime in settings

#### Manual Sync

Need an immediate update? Click **Sync Now** in Settings → Filter Lists. Updates check automatically every 24 hours.

#### Built-in Filter Lists

| Name | Type | Purpose | Default |
|------|------|---------|----------|
| EasyList | Ads | Primary ad blocker | ✅ Enabled |
| EasyPrivacy | Trackers | Tracking prevention | ✅ Enabled |
| Fanboy's Annoyances | UI | Pop-ups & clutter | ✅ Enabled |
| EasyList Cookie List | Privacy | Cookie notices | ⚪ Disabled |
| Fanboy's Social | Social | Social media widgets | ⚪ Disabled |
| I Don't Care About Cookies | Privacy | Auto-accept cookies | ⚪ Disabled |

### Search Engine & Autocomplete Configuration

#### Supported Search Engines

1. **DuckDuckGo** (default) — Privacy-focused, no tracking
2. **Google** — Full-featured search
3. **Bing** — Microsoft's search engine
4. **Brave** — Brave Search with optional API key
5. **Ecosia** — Eco-friendly search engine
6. **SearXNG** — Self-hosted private meta-search (custom instance URL required)

**To change:** Settings → General → Search Engine

#### Autocomplete Providers

1. **None** (default) — No autocomplete
2. **DuckDuckGo** — Fast, privacy-respecting suggestions
3. **Google** — Full suggestion history
4. **Brave** — Requires free API key from [api.search.brave.com](https://api.search.brave.com)

**To change:** Settings → Autocomplete → Provider

### Creating Custom Filter Lists

See [adblock-generator/README.md](adblock-generator/) to create your own filter lists in AdBlock Plus format.

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
