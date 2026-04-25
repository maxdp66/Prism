# 🔧 AdBlock Generator

A Rust-based utility to convert standard AdBlock filter lists into WebKit-compatible content rule lists for use in Prism and other Safari-based browsers.

## Overview

The AdBlock Generator parses AdBlock Plus (ABP) filter syntax and compiles it into a format compatible with Safari's `WKContentRuleList`, enabling efficient content blocking at the network level.

## Features

- ✅ Parses standard AdBlock Plus (ABP) syntax
- ✅ Supports URL pattern matching and domain restrictions
- ✅ Converts rules to WebKit JSON format
- ✅ Optimizes rules for performance
- ✅ Handles comments and metadata
- ✅ Reports statistics on compiled rules

## Building

### Prerequisites

- Rust 1.70+ (install via [rustup](https://rustup.rs/))
- Cargo package manager

### Compile

```bash
cd adblock-generator
cargo build --release
```

The compiled binary will be in `target/release/adblock-generator`

## Usage

### Basic Usage

```bash
./adblock-generator <filter_file> [output_file]
```

**Arguments:**
- `filter_file` — Path to AdBlock filter list file
- `output_file` — (Optional) Output file path. Defaults to `compiled_rules.json`

### Example

```bash
# Convert EasyList to WebKit format
./adblock-generator easylist.txt easylist-rules.json

# Convert and use default output name
./adblock-generator fanboys-annoyance.txt
# Creates: compiled_rules.json
```

## Filter Syntax

The generator supports standard AdBlock Plus syntax:

### Basic Rules

```
# Block all ads.png files
ads.png

# Block with domain restriction
ads.png|$domain=example.com

# Exact match
||ads.example.com^

# Pattern matching
/banner/ads/*
```

### Comments

```
# This is a comment
! This is also a comment (ABP style)
```

### Special Syntax

- `||` — Domain anchor (matches domain)
- `^` — Separator character (matches /, ?, :, etc.)
- `$` — Filter options
- `|` — URL anchor (start/end of URL)
- `@@` — Exception (whitelist) rule

## Output Format

The generator produces a JSON file compatible with WebKit's `WKContentRuleList`:

```json
{
  "trigger": {
    "url-filter": "regex-pattern",
    "resource-type": ["image", "script"],
    "if-domain": ["example.com"]
  },
  "action": {
    "type": "block"
  }
}
```

## Integration with Prism

Prism's `FilterListManager` uses this tool to:

1. Download filter lists from configured URLs
2. Call `adblock-generator` to compile rules
3. Store compiled rules in `WKContentRuleListStore`
4. Inject rules into `WKWebView` for all pages

See [Prism Architecture](../README.md#-architecture) for more details.

## Performance Notes

- Rules are compiled once and cached
- Compiled rules use optimized regex patterns
- Refresh frequency is configurable (default: 24 hours)
- Large filter lists (10,000+ rules) process in seconds

## Testing

### Test Filters

A test filter file is included at `test_filters.txt`:

```bash
./adblock-generator test_filters.txt test_output.json
```

### Validation

The output JSON can be validated against WebKit's schema using standard JSON validators.

## Troubleshooting

### Build Issues

**Error: `rustc` not found**

Install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Filter Compilation

**Rule not working**

1. Verify the rule syntax against [AdBlock Plus documentation](https://adblockplus.org/en/filter-cheatsheet)
2. Check domain restrictions with `$domain=` filters
3. Test with simple patterns first

## Contributing

To improve the AdBlock Generator:

1. Propose changes via GitHub issues
2. Submit pull requests with improvements
3. Include test cases for new syntax support
4. Update this README for user-facing changes

## License

Prism and all components, including the AdBlock Generator, are licensed under the MIT License. See [LICENSE](../LICENSE) for details.

---

**Questions?** Open an issue on [GitHub](https://github.com/yourusername/prism/issues)
