# sge-parser

A Ruby gem for scraping search engine results using
[Ferrum](https://github.com/rubycdp/ferrum) with built-in stealth injection,
structured screenshot naming, and AI Overview capture support.

## Features

- **Stealth browsing** — Comprehensive anti-detection patches (WebGL, canvas,
  chrome.runtime, permissions, window dimensions, cdc\_ cleanup) injected via
  CDP before any page load.
- **Human-like behavior** — Navigates to google.com, clicks search box, types
  character-by-character with random delays.
- **Provider pattern** — Google today, Bing tomorrow. Easy to extend.
- **Structured screenshots** — Filenames follow
  `YYYYMMDD_HHMMSS_action_query_provider.png`.
- **AI Overview detection** — Detects and screenshots Google's AI-generated
  overviews.
- **CAPTCHA detection** — Raises `SGE::Parser::CaptchaError` instead of
  returning garbage.
- **Heavy test coverage** — All browser interaction mocked; no Chrome required
  to run the suite.

## Installation

Add to your Gemfile:

```ruby
gem "sge-parser"
```

Or install directly:

```bash
gem install sge-parser
```

Requires Ruby >= 3.0 and a working Chrome/Chromium installation for Ferrum.

## Quick Start

```ruby
require "sge-parser"

# Headless mode (default, uses headless: :new)
results = SGE::Parser.search("turing machine", warm_up: true)

puts results[:title]
puts results[:results_count]
puts results[:screenshot]

if results[:ai_overview_present]
  puts results[:ai_overview_text]
  puts results[:ai_overview_screenshot]
end
```

## Configuration

```ruby
SGE::Parser.configure do |config|
  config.screenshot_dir = File.expand_path("screenshots", __dir__)
  config.browser_options  = { headless: false }  # Watch the browser
  config.default_timeout  = 30
end
```

## Usage

### Basic Search

```ruby
results = SGE::Parser.search(
  "coffee makers",
  provider: :google,
  action:   :search,
  screenshot: true,
  warm_up: true
)
```

Returns a hash:

```ruby
{
  provider:      :google,
  title:         "coffee makers - Google Search",
  results_count: 12,
  has_results:   true,
  url:           "https://www.google.com/search?...",
  screenshot:    "screenshots/20240603_153045_search_coffee-makers_google.png"
}
```

### AI Overview Capture

For queries that trigger Google's AI Overview (e.g. "turing machine"):

```ruby
results = SGE::Parser.search("turing machine", warm_up: true)

if results[:ai_overview_present]
  puts results[:ai_overview_text]
  puts results[:ai_overview_screenshot]
end
```

### Custom AI Overview Selector

Google changes their DOM frequently. If the default selector drifts, override
it:

```ruby
SGE::Parser.search(
  "turing machine",
  provider_options: { ai_overview_selector: 'div.new-google-class' }
)
```

### Screenshot Naming Convention

```
YYYYMMDD_HHMMSS_action_query_provider.png
```

| Segment   | Example                 | Description                   |
| --------- | ----------------------- | ----------------------------- |
| Timestamp | `20240603_153045`       | UTC time of capture           |
| Action    | `search`, `ai_overview` | What triggered the screenshot |
| Query     | `turing-machine`        | Sanitized search term         |
| Provider  | `google`                | Search engine used            |

### Headless vs Visible

```ruby
# New headless mode (default, less detectable than old headless)
SGE::Parser.search("ruby gems")

# Visible browser — useful for debugging CAPTCHAs
SGE::Parser.configure do |config|
  config.browser_options = { headless: false }
end
```

## Stealth Measures

The following are patched before any navigation via
`Page.addScriptToEvaluateOnNewDocument`:

| Property                        | Patch                                             |
| ------------------------------- | ------------------------------------------------- |
| `navigator.webdriver`           | `undefined`                                       |
| `window.chrome`                 | Full `runtime`, `app`, `csi`, `loadTimes` objects |
| `navigator.plugins`             | Realistic plugin array                            |
| `navigator.languages`           | `["en-US", "en"]`                                 |
| `navigator.platform`            | `"MacIntel"`                                      |
| `navigator.hardwareConcurrency` | `8`                                               |
| `navigator.deviceMemory`        | `8`                                               |
| WebGL vendor/renderer           | `"Intel Inc."` / `"Intel Iris OpenGL Engine"`     |
| `window.outerWidth/Height`      | Match `innerWidth/Height`                         |
| `screen.*`                      | Realistic color/ pixel depth, avail dimensions    |
| `cdc_` / `wdc_` variables       | Removed from `window`                             |
| `navigator.permissions.query`   | Spoofed notification response                     |

Plus behavioral mimicry: google.com first, click search box, type chars with
random delays, press Enter.

## Architecture

```
lib/sge/parser/
├── browser.rb      # Ferrum wrapper + comprehensive stealth JS
├── screenshot.rb   # Filename generation & directory management
├── providers/
│   ├── base.rb     # Shared CAPTCHA detection & delays
│   └── google.rb   # human_search, parsing, AI overview detection
```

## Testing

```bash
bundle exec rspec
```

All specs use `instance_double` — no Chrome required.

## CAPTCHA Handling

If Google serves a CAPTCHA, `SGE::Parser::CaptchaError` is raised. Common fixes:

- Use `warm_up: true` to accumulate cookies
- Ensure persistent `user-data-dir` (default in Browser)
- Switch to `headless: false` for debugging
- Check screenshot to see exactly what Google served

## License

MIT
