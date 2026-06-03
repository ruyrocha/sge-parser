module SGE
  module Parser
    module Providers
      class Google < Base
        BASE_URL = "https://www.google.com/search".freeze
        AI_OVERVIEW_SELECTOR = 'div[data-attrid="kc:/search/ai_overview"]'.freeze

        attr_reader :ai_overview_selector

        def initialize(ai_overview_selector: AI_OVERVIEW_SELECTOR)
          @ai_overview_selector = ai_overview_selector
        end

        def search(browser, query)
          url = build_url(query)
          browser.go_to(url)
          random_delay(min: 2.0, max: 4.0)

          if detect_captcha?(browser)
            raise CaptchaError, "Google CAPTCHA detected for query: #{query}"
          end

          parse_results(browser)
        end

        def ai_overview?(browser)
          !!browser.at_css(ai_overview_selector)
        end

        def ai_overview_text(browser)
          element = browser.at_css(ai_overview_selector)
          return nil unless element

          element.inner_text
        end

        private

        def build_url(query)
          params = URI.encode_www_form(
            q: query,
            hl: "en",
            gl: "us",
            gbv: "1"
          )
          "#{BASE_URL}?#{params}"
        end

        def parse_results(browser)
          {
            provider: :google,
            title: browser.title,
            results_count: browser.css("h3").length,
            has_results: !browser.css("#search").empty?,
            url: browser.evaluate("window.location.href"),
            ai_overview_present: ai_overview?(browser),
            ai_overview_text: ai_overview_text(browser),
            ai_overview_selector: ai_overview_selector
          }
        end
      end
    end
  end
end
