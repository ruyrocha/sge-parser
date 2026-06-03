require_relative "lib/sge/parser/version"

Gem::Specification.new do |spec|
  spec.name          = "sge-parser"
  spec.version       = SGE::Parser::VERSION
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Search engine result parser with screenshot capabilities"
  spec.description   = "A Ruby gem for scraping search engine results using Ferrum with stealth injection and structured screenshot naming"
  spec.homepage      = "https://github.com/yourusername/sge-parser"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ferrum", "~> 0.17"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
end
