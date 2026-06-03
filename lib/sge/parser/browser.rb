module SGE
  module Parser
    class Browser
      attr_reader :options, :browser

      DEFAULT_OPTIONS = {
        headless: true,
        window_size: [1920, 1080],
        browser_options: {
          "disable-blink-features" => "AutomationControlled",
          "disable-features" => "IsolateOrigins,site-per-process"
        }
      }.freeze

      STEALTH_JS = <<~JS
        Object.defineProperty(navigator, "webdriver", { get: () => undefined });
        window.chrome = { runtime: {} };
        Object.defineProperty(navigator, "plugins", {
          get: () => [
            { name: "Chrome PDF Plugin", filename: "internal-pdf-viewer" },
            { name: "Chrome PDF Viewer", filename: "mhjfbmdgcfjbbpaeojofohoefgiehjai" }
          ]
        });
        Object.defineProperty(navigator, "languages", { get: () => ["en-US", "en"] });
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
          parameters.name === "notifications"
            ? Promise.resolve({ state: Notification.permission })
            : originalQuery(parameters)
        );
      JS

      def initialize(options = {})
        @options = DEFAULT_OPTIONS.merge(options)
        @browser = nil
      end

      def start
        @browser = Ferrum::Browser.new(**@options)
        inject_stealth
        @browser
      end

      def stop
        @browser&.quit
        @browser = nil
      end

      def go_to(url)
        start unless @browser
        @browser.go_to(url)
      end

      def screenshot(**opts)
        @browser.screenshot(**opts)
      end

      def screenshot_element(path:, selector:)
        @browser.screenshot(path: path, selector: selector)
      end

      def title
        @browser.title
      end

      def css(selector)
        @browser.css(selector)
      end

      def at_css(selector)
        @browser.at_css(selector)
      end

      def evaluate(script)
        @browser.evaluate(script)
      end

      private

      def inject_stealth
        @browser.page.command("Page.addScriptToEvaluateOnNewDocument", source: STEALTH_JS)
      end
    end
  end
end
