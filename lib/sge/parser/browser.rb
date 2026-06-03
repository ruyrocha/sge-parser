module SGE
  module Parser
    class Browser
      attr_reader :options, :browser

      DEFAULT_OPTIONS = {
        headless: :new,
        window_size: [1366, 768],
        browser_options: {
          'disable-blink-features' => 'AutomationControlled',
          'user-data-dir' => File.expand_path('~/.config/sge-parser-chrome'),
          'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
        }
      }.freeze

      STEALTH_JS = <<~JS
        // 1. Webdriver
        Object.defineProperty(navigator, "webdriver", { get: () => undefined });

        // 2. Chrome runtime (FULL object)
        if (!window.chrome) { window.chrome = {}; }
        window.chrome.runtime = {
          connect: function() { return { onDisconnect: { addListener: function() {} }, onMessage: { addListener: function() {} }, postMessage: function() {}, disconnect: function() {} }; },
          sendMessage: function() {}
        };
        window.chrome.app = {
          isInstalled: false,
          getDetails: function() { return null; },
          getIsInstalled: function() { return false; },
          InstallState: { DISABLED: 'disabled', INSTALLED: 'installed', NOT_INSTALLED: 'not_installed' },
          RunningState: { CANNOT_RUN: 'cannot_run', READY_TO_RUN: 'ready_to_run', RUNNING: 'running' }
        };
        window.chrome.csi = function() { return {}; };
        window.chrome.loadTimes = function() {
          return {
            commitLoadTime: Date.now() / 1000,
            connectionInfo: 'h2',
            finishDocumentLoadTime: Date.now() / 1000,
            finishLoadTime: Date.now() / 1000,
            firstPaintAfterLoadTime: 0,
            firstPaintTime: Date.now() / 1000,
            navigationType: 'Other',
            npnNegotiatedProtocol: 'h2',
            requestTime: Date.now() / 1000 - 0.5,
            startLoadTime: Date.now() / 1000 - 0.5,
            wasAlternateProtocolAvailable: false,
            wasFetchedViaSpdy: true,
            wasNpnNegotiated: true
          };
        };

        // 3. Plugins (realistic)
        Object.defineProperty(navigator, "plugins", {
          get: () => [
            { name: "Chrome PDF Plugin", filename: "internal-pdf-viewer", description: "Portable Document Format" },
            { name: "Chrome PDF Viewer", filename: "mhjfbmdgcfjbbpaeojofohoefgiehjai", description: "" },
            { name: "Native Client", filename: "internal-nacl-plugin", description: "" }
          ]
        });

        // 4. Languages
        Object.defineProperty(navigator, "languages", { get: () => ["en-US", "en"] });

        // 5. Platform
        Object.defineProperty(navigator, "platform", { get: () => "MacIntel" });

        // 6. Hardware
        Object.defineProperty(navigator, "hardwareConcurrency", { get: () => 8 });
        Object.defineProperty(navigator, "deviceMemory", { get: () => 8 });

        // 7. WebGL - hide SwiftShader (CRITICAL)
        const getParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(param) {
          if (param === 37445) return "Intel Inc.";
          if (param === 37446) return "Intel Iris OpenGL Engine";
          return getParameter.call(this, param);
        };
        const getParameter2 = WebGL2RenderingContext.prototype.getParameter;
        WebGL2RenderingContext.prototype.getParameter = function(param) {
          if (param === 37445) return "Intel Inc.";
          if (param === 37446) return "Intel Iris OpenGL Engine";
          return getParameter2.call(this, param);
        };

        // 8. Window dimensions (headless leak)
        Object.defineProperty(window, "outerWidth", { get: () => window.innerWidth });
        Object.defineProperty(window, "outerHeight", { get: () => window.innerHeight });

        // 9. Screen
        Object.defineProperty(screen, "colorDepth", { get: () => 24 });
        Object.defineProperty(screen, "pixelDepth", { get: () => 24 });
        Object.defineProperty(screen, "availWidth", { get: () => screen.width });
        Object.defineProperty(screen, "availHeight", { get: () => screen.height });

        // 10. Remove cdc_ variables (ChromeDriver/CDP leak)
        Object.keys(window).forEach(function(key) {
          if (key.includes("cdc_") || key.includes("wdc_")) {
            delete window[key];
          }
        });

        // 11. Permissions
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = function(parameters) {
          return parameters.name === "notifications"
            ? Promise.resolve({ state: Notification.permission, onchange: null })
            : originalQuery(parameters);
        };
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

      def mouse
        @browser.mouse
      end

      def keyboard
        @browser.keyboard
      end

      def warm_up
        go_to('https://www.google.com')
        sleep(rand(2.0..4.0))
      end

      def human_search(query)
        go_to('https://www.google.com/?hl=en&gl=us')
        sleep(rand(1.0..3.0))

        evaluate(<<~JS)
          (function() {
            const box = document.querySelector('textarea[name="q"]') ||#{' '}
                        document.querySelector('input[name="q"]');
            if (box) {
              box.focus();
              box.click();
              return true;
            }
            return false;
          })()
        JS
        sleep(rand(0.5..1.5))

        query.chars.each do |char|
          keyboard.type(char)
          sleep(rand(0.05..0.15))
        end
        sleep(rand(0.3..0.8))

        keyboard.type(:Return)
        sleep(rand(3.0..6.0))
      end

      private

      def inject_stealth
        @browser.page.command('Page.addScriptToEvaluateOnNewDocument', source: STEALTH_JS)
      end
    end
  end
end
