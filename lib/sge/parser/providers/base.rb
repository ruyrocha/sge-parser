module SGE
  module Parser
    module Providers
      class Base
        def search(_browser, _query)
          raise NotImplementedError
        end

        protected

        def detect_captcha?(browser)
          !!browser.at_css('form[action="/sorry"]') ||
            !!browser.at_css("#captcha") ||
            browser.title.to_s.include?("unusual traffic") ||
            browser.title.to_s.include?("sorry")
        end

        def random_delay(min: 1.0, max: 3.0)
          sleep(rand(min..max))
        end
      end
    end
  end
end
