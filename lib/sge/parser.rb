require 'ferrum'
require 'fileutils'

require_relative 'parser/version'
require_relative 'parser/config'
require_relative 'parser/browser'
require_relative 'parser/screenshot'
require_relative 'parser/providers'
require_relative 'parser/providers/base'
require_relative 'parser/providers/google'

module SGE
  module Parser
    class Error < StandardError; end
    class CaptchaError < Error; end

    @config = Config.new

    class << self
      attr_accessor :config

      def configure
        yield(config)
      end

      def search(query, provider: :google, action: :search, screenshot: true, provider_options: {}, warm_up: false)
        provider_instance = Providers.build(provider, **provider_options)
        browser = Browser.new

        begin
          browser.start
          browser.warm_up if warm_up
          results = provider_instance.search(browser, query)

          if screenshot
            screenshot_manager = Screenshot.new
            path = screenshot_manager.capture(browser, action: action, query: query, provider: provider)
            results[:screenshot] = path
          end

          if results[:ai_overview_present] && screenshot
            ai_path = screenshot_manager.capture_element(
              browser,
              selector: results[:ai_overview_selector],
              action: :ai_overview,
              query: query,
              provider: provider
            )
            results[:ai_overview_screenshot] = ai_path
          end

          results
        ensure
          browser.stop
        end
      end
    end
  end
end
