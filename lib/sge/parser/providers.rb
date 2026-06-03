module SGE
  module Parser
    module Providers
      def self.build(name)
        case name.to_sym
        when :google then Google.new
        else raise ArgumentError, "Unknown provider: #{name}"
        end
      end
    end
  end
end
