# sge-parser

A Ruby gem for scraping search engine results using
[Ferrum](https://github.com/rubycdp/ferrum) with built-in stealth injection,
structured screenshot naming, and AI Overview capture support.

## Features

- **Stealth browsing** — Injects anti-detection scripts via Chrome DevTools
  Protocol before any page load.
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

results = SGE::Parser.search("turing machine")

puts results[:title]
# => "turing machine - Google Search"

puts results[:results_count]
# => 12

puts results[:screenshot]
# => "screenshots/20240603_153045_search_turing-machine_google.png"
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
  screenshot: true
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
results = SGE::Parser.search("turing machine")

if results[:ai_overview_present]
  puts results[:ai_overview_text]
  # => "A Turing machine is a mathematical model of computation..."

  puts results[:ai_overview_screenshot]
  # => "screenshots/20240603_153045_ai-overview_turing-machine_google.png"
end
```

### Custom AI Overview Selector

Google changes their DOM frequently. If the default selector drifts, override
it:

```ruby
provider = SGE::Parser::Providers::Google.new(
  ai_overview_selector: 'div.new-google-class'
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

Special characters in queries are replaced with hyphens and truncated to 50
characters.

### Headless vs Visible

```ruby
# Headless (default, CI-friendly)
SGE::Parser.search("ruby gems")

# Visible browser — useful for debugging CAPTCHAs
SGE::Parser.configure do |config|
  config.browser_options = { headless: false }
end
```

## Architecture

```
lib/sge/parser/
├── browser.rb      # Ferrum wrapper + stealth JS injection
├── screenshot.rb   # Filename generation & directory management
├── providers/
│   ├── base.rb     # Shared CAPTCHA detection & delays
│   └── google.rb   # URL building, parsing, AI overview detection
```

### Adding a New Provider

1. Create `lib/sge/parser/providers/bing.rb`:

```ruby
module SGE
  module Parser
    module Providers
      class Bing < Base
        BASE_URL = "https://www.bing.com/search".freeze

        def search(browser, query)
          browser.go_to("#{BASE_URL}?q=#{URI.encode_www_form_component(query)}")
          random_delay

          raise CaptchaError if detect_captcha?(browser)

          { provider: :bing, title: browser.title }
        end
      end
    end
  end
end
```

1. Register it in `lib/sge/parser/providers.rb`:

```ruby
def self.build(name)
  case name.to_sym
  when :google then Google.new
  when :bing   then Bing.new
  else raise ArgumentError, "Unknown provider: #{name}"
  end
end
```

## Testing

```bash
bundle exec rspec
```

All specs use `instance_double` — no Chrome required. The suite runs in under a
second.

### Test Structure

| Spec                 | Coverage                                                                             |
| -------------------- | ------------------------------------------------------------------------------------ |
| `parser_spec.rb`     | Integration-level API, screenshot toggling, AI overview branching, browser lifecycle |
| `browser_spec.rb`    | Stealth injection, CDP command verification, delegation, element screenshots         |
| `screenshot_spec.rb` | Filename generation, sanitization, truncation, element capture                       |
| `google_spec.rb`     | URL building, result parsing, CAPTCHA detection, AI overview detection/text          |

## CAPTCHA Handling

If Google serves a CAPTCHA or "unusual traffic" page,
`SGE::Parser::CaptchaError` is raised with the query in the message. The browser
is still properly quit via `ensure`.

Common causes:

- **Datacenter IP** — Use a residential proxy.
- **No human delays** — The Google provider already adds 2–4s randomized delays.
- **Fresh profile** — Visit a few normal sites first to accumulate cookies.

## Stealth Script

The following properties are patched before any navigation:

- `navigator.webdriver` → `undefined`
- `navigator.plugins` → realistic plugin array
- `navigator.languages` → `["en-US", "en"]`
- `navigator.permissions.query` → spoofed notification response
- `window.chrome` → `{ runtime: {} }`

Injected via `Page.addScriptToEvaluateOnNewDocument` so it runs before page
scripts.

## License

MIT
