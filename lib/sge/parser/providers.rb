module SGE
  module Parser
    module Providers
      def self.build(name, **opts)
        case name.to_sym
        when :google then Google.new(**opts)
        else raise ArgumentError, "Unknown provider: #{name}"
        end
      end
    end
  end
end
