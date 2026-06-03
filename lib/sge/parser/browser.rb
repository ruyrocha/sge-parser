module SGE
  module Parser
    class Browser
      attr_reader :options, :browser

      DEFAULT_OPTIONS = {
        headless: true,
        window_size: [1920, 1080],
        browser_options: {
          'disable-blink-features' => 'AutomationControlled',
          'disable-features' => 'IsolateOrigins,site-per-process',
          'disable-web-security' => nil,
          'disable-features' => 'BlockInsecurePrivateNetworkRequests',
          'user-data-dir' => File.expand_path('~/.config/sge-parser-chrome')
        }
      }.freeze

      STEALTH_JS = <<~JS
        // Override navigator.webdriver
        Object.defineProperty(navigator, "webdriver", { get: () => undefined });

        // Chrome runtime
        window.chrome = { runtime: {} };

        // Plugins with realistic structure
        Object.defineProperty(navigator, "plugins", {
          get: () => [
            { name: "Chrome PDF Plugin", filename: "internal-pdf-viewer", description: "Portable Document Format", version: "undefined", length: 1, item: () => null, namedItem: () => null },
            { name: "Chrome PDF Viewer", filename: "mhjfbmdgcfjbbpaeojofohoefgiehjai", description: "Portable Document Format", version: "undefined", length: 1, item: () => null, namedItem: () => null },
            { name: "Native Client", filename: "internal-nacl-plugin", description: "", version: "undefined", length: 2, item: () => null, namedItem: () => null }
          ]
        });

        // Languages
        Object.defineProperty(navigator, "languages", { get: () => ["en-US", "en"] });

        // MimeTypes
        Object.defineProperty(navigator, "mimeTypes", { get: () => [1, 2] });

        // WebGL vendor/renderer spoofing
        const getParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(parameter) {
          if (parameter === 37445) return "Intel Inc.";
          if (parameter === 37446) return "Intel Iris OpenGL Engine";
          if (parameter === 37447) return "";
          return getParameter(parameter);
        };

        // Permissions API
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
          parameters.name === "notifications"
            ? Promise.resolve({ state: Notification.permission, onchange: null })
            : originalQuery(parameters)
        );

        // Canvas fingerprint randomization
        const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
        const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;

        HTMLCanvasElement.prototype.toDataURL = function(type) {
          if (this.width > 0 && this.height > 0) {
            const context = this.getContext("2d");
            const imageData = context.getImageData(0, 0, this.width, this.height);
            for (let i = 0; i < imageData.data.length; i += 4) {
              imageData.data[i] = imageData.data[i] + 1;
            }
            context.putImageData(imageData, 0, 0);
          }
          return originalToDataURL.apply(this, arguments);
        };

        // Notification permission
        Object.defineProperty(Notification, "permission", { get: () => "default" });

        // Device memory
        Object.defineProperty(navigator, "deviceMemory", { get: () => 8 });

        // Hardware concurrency
        Object.defineProperty(navigator, "hardwareConcurrency", { get: () => 4 });

        // Platform
        Object.defineProperty(navigator, "platform", { get: () => "MacIntel" });

        // Max touch points
        Object.defineProperty(navigator, "maxTouchPoints", { get: () => 0 });

        // PDF viewer enabled
        Object.defineProperty(navigator, "pdfViewerEnabled", { get: () => true });

        // Bluetooth
        Object.defineProperty(navigator, "bluetooth", { get: () => undefined });

        // Keyboard
        Object.defineProperty(navigator, "keyboard", { get: () => undefined });

        // Media capabilities
        Object.defineProperty(navigator, "mediaCapabilities", { get: () => ({ decodingInfo: () => Promise.resolve({}) }) });

        // Wake lock
        Object.defineProperty(navigator, "wakeLock", { get: () => undefined });

        // Credentials
        Object.defineProperty(navigator, "credentials", { get: () => undefined });

        // Clipboard
        Object.defineProperty(navigator, "clipboard", { get: () => undefined });

        // Payment handler
        Object.defineProperty(navigator, "paymentHandler", { get: () => undefined });

        // Presentation
        Object.defineProperty(navigator, "presentation", { get: () => undefined });

        // Scheduling
        Object.defineProperty(navigator, "scheduling", { get: () => undefined });

        // Storage buckets
        Object.defineProperty(navigator, "storageBuckets", { get: () => undefined });

        // Window outer dimensions (headless leak)
        Object.defineProperty(window, "outerWidth", { get: () => window.innerWidth });
        Object.defineProperty(window, "outerHeight", { get: () => window.innerHeight });

        // Screen availWidth/availHeight
        Object.defineProperty(screen, "availWidth", { get: () => screen.width });
        Object.defineProperty(screen, "availHeight", { get: () => screen.height });

        // Removecdc_ variables if present (ChromeDriver leak)
        Object.keys(window).forEach(key => {
          if (key.includes("cdc_") || key.includes("wdc_")) {
            delete window[key];
          }
        });
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

      def warm_up
        go_to('https://example.com')
        sleep(rand(1.0..2.0))
        go_to('https://github.com')
        sleep(rand(1.0..2.0))
      end

      def human_delay(min: 2.0, max: 5.0)
        sleep(rand(min..max))
      end

      def move_mouse_randomly
        3.times do
          x = rand(100..800)
          y = rand(100..600)
          mouse.move(x: x, y: y)
          sleep(rand(0.3..1.2))
        end
      end

      private

      def inject_stealth
        @browser.page.command('Page.addScriptToEvaluateOnNewDocument', source: STEALTH_JS)
      end
    end
  end
end
