require "time"

module SGE
  module Parser
    class Screenshot
      attr_reader :config

      def initialize(config = Parser.config)
        @config = config
        ensure_directory
      end

      def capture(browser, action:, query:, provider:)
        path = build_path(action: action, query: query, provider: provider)
        browser.screenshot(path: path)
        path
      end

      def capture_element(browser, selector:, action:, query:, provider:)
        path = build_path(action: action, query: query, provider: provider)
        browser.screenshot_element(path: path, selector: selector)
        path
      end

      def build_path(action:, query:, provider:)
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        safe_query = sanitize(query)
        safe_provider = sanitize(provider.to_s)
        safe_action = sanitize(action.to_s)

        filename = "#{timestamp}_#{safe_action}_#{safe_query}_#{safe_provider}.png"
        File.join(@config.screenshot_dir, filename)
      end

      private

      def ensure_directory
        FileUtils.mkdir_p(@config.screenshot_dir)
      end

      def sanitize(str)
        str.gsub(/[^a-zA-Z0-9\-]/, "-")
           .gsub(/-+/, "-")
           .downcase[0, 50]
      end
    end
  end
end
