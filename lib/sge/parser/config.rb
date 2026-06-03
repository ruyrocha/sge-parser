module SGE
  module Parser
    class Config
      attr_accessor :screenshot_dir, :browser_options, :default_timeout

      def initialize
        @screenshot_dir = File.expand_path("screenshots", Dir.pwd)
        @browser_options = {}
        @default_timeout = 30
      end
    end
  end
end
