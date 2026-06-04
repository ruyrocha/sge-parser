module SGE
  module Parser
    module Providers
      class Google < Base
        BASE_URL = 'https://www.google.com/search'.freeze

        # CSS selectors ordered by priority — first match wins.
        # Uses partial attribute matching (*=) to survive Google's
        # frequent data-attrid value changes (e.g. "kc:/search/ai_overview"
        # vs "kc:/search/ai_overview:" vs unknown future values).
        AI_OVERVIEW_SELECTORS = [
          'div[data-attrid*="ai_overview"]',
          'div[data-attrid="kc:/search/ai_overview"]',
          'div[data-attrid="kc:/search/ai_overview:"]'
        ].freeze

        # Heading text used as text-based fallback when no CSS selector matches
        AI_OVERVIEW_HEADING = 'AI Overview'.freeze

        attr_reader :ai_overview_selector

        def initialize(ai_overview_selector: nil)
          @ai_overview_selector = ai_overview_selector
        end

        def search(browser, query)
          browser.human_search(query)

          raise CaptchaError, "Google CAPTCHA detected for query: #{query}" if detect_captcha?(browser)

          parse_results(browser)
        end

        def ai_overview?(browser)
          !!find_ai_overview(browser)
        end

        def ai_overview_text(browser)
          element = find_ai_overview(browser)
          return nil unless element

          element.inner_text
        end

        # Extracts reference links from the AI Overview container.
        # Returns an array of hashes with :index, :text, and :url keys.
        def ai_overview_references(browser)
          element = find_ai_overview(browser)
          return [] unless element

          selector = resolved_selector(browser)

          browser.evaluate(<<~JS)
            (function() {
              var el = document.querySelector(#{selector.to_json});
              if (!el) return [];
              var links = el.querySelectorAll('a[href]');
              return Array.from(links).filter(function(a) {
                return a.querySelector('sup') || a.getAttribute('data-ved');
              }).map(function(a, i) {
                return { index: i + 1, text: a.textContent.trim(), url: a.href };
              });
            })()
          JS
        end

        # Diagnostic method — call when AI Overview is visible on the page
        # but ai_overview? returns false. Returns a hash of debug info
        # showing what selectors matched and what data-attrid values exist.
        def diagnose_ai_overview(browser)
          {
            configured_selector: @ai_overview_selector,
            fallback_selectors: AI_OVERVIEW_SELECTORS,
            selector_matches: AI_OVERVIEW_SELECTORS.map { |s|
              { selector: s, found: !!browser.at_css(s) }
            },
            heading_found: browser.evaluate(<<~JS),
              (function() {
                var all = document.querySelectorAll('span, div, h1, h2, h3, p');
                for (var i = 0; i < all.length; i++) {
                  if (all[i].textContent.trim() === 'AI Overview') return true;
                }
                return false;
              })()
            JS
            attrid_values: browser.evaluate(<<~JS),
              (function() {
                return Array.from(document.querySelectorAll('[data-attrid]'))
                  .map(function(el) { return el.getAttribute('data-attrid'); })
                  .filter(function(v) { return v.indexOf('ai') !== -1 || v.indexOf('overview') !== -1 || v.indexOf('kc') !== -1; });
              })()
            JS
            heading_containers: browser.evaluate(<<~JS)
              (function() {
                var all = document.querySelectorAll('span, div, h1, h2, h3, p');
                for (var i = 0; i < all.length; i++) {
                  if (all[i].textContent.trim() === 'AI Overview') {
                    var node = all[i];
                    var info = [];
                    for (var j = 0; j < 6 && node; j++) {
                      info.push({
                        tag: node.tagName,
                        id: node.id || null,
                        classes: node.className ? node.className.split(' ').slice(0, 5) : [],
                        attrs: Array.from(node.attributes || []).map(function(a) { return a.name; }).filter(function(n) { return n.startsWith('data-') || n.startsWith('js'); })
                      });
                      node = node.parentElement;
                    }
                    return info;
                  }
                }
                return null;
              })()
            JS
          }
        end

        private

        # Tries each detection strategy in order:
        # 1. Custom selector (if provided via constructor)
        # 2. CSS attribute selectors with partial matching
        # 3. Text-based heading search (finds "AI Overview" text and walks up to container)
        def find_ai_overview(browser)
          # Try custom selector first if provided
          if @ai_overview_selector
            element = browser.at_css(@ai_overview_selector)
            return element if element
          end

          # Try each fallback selector
          AI_OVERVIEW_SELECTORS.each do |selector|
            element = browser.at_css(selector)
            return element if element
          end

          # Text-based fallback: find "AI Overview" heading and walk up to container
          find_by_heading_text(browser)
        end

        # Last-resort detection: searches for the "AI Overview" heading text
        # in the DOM, then walks up the ancestor tree to find the main
        # container (heuristic: first ancestor with >100 chars of text content).
        # Marks the found container with a data attribute so at_css can retrieve it.
        def find_by_heading_text(browser)
          selector = browser.evaluate(<<~JS)
            (function() {
              var all = document.querySelectorAll('span, div, h1, h2, h3, p');
              for (var i = 0; i < all.length; i++) {
                if (all[i].textContent.trim() === 'AI Overview') {
                  var node = all[i];
                  for (var j = 0; j < 5; j++) {
                    node = node.parentElement;
                    if (!node) return null;
                    if (node.textContent.trim().length > 100) {
                      node.setAttribute('data-sge-ai-overview', 'true');
                      return 'div[data-sge-ai-overview="true"]';
                    }
                  }
                }
              }
              return null;
            })()
          JS

          return nil unless selector
          browser.at_css(selector)
        end

        # Returns the selector that actually matched, for use in diagnostics
        # and reference link extraction.
        def resolved_selector(browser)
          return @ai_overview_selector if @ai_overview_selector && browser.at_css(@ai_overview_selector)

          AI_OVERVIEW_SELECTORS.find { |s| browser.at_css(s) } ||
            'div[data-sge-ai-overview="true"]'
        end

        def parse_results(browser)
          {
            provider: :google,
            title: browser.title,
            results_count: browser.css('h3').length,
            has_results: !browser.css('#search').empty?,
            url: browser.evaluate('window.location.href'),
            ai_overview_present: ai_overview?(browser),
            ai_overview_text: ai_overview_text(browser),
            ai_overview_references: ai_overview_references(browser),
            ai_overview_selector: resolved_selector(browser)
          }
        end
      end
    end
  end
end
