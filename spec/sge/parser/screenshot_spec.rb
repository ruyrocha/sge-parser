require "spec_helper"

RSpec.describe SGE::Parser::Screenshot do
  let(:config) { SGE::Parser::Config.new }
  let(:screenshot) { described_class.new(config) }
  let(:browser) { instance_double(SGE::Parser::Browser) }

  before do
    config.screenshot_dir = Dir.mktmpdir
  end

  after do
    FileUtils.rm_rf(config.screenshot_dir)
  end

  describe "#build_path" do
    it "generates a filename with timestamp, action, query, and provider" do
      path = screenshot.build_path(action: :search, query: "coffee makers", provider: :google)
      basename = File.basename(path)

      expect(basename).to match(/^\d{8}_\d{6}_search_coffee-makers_google\.png$/)
      expect(File.dirname(path)).to eq(config.screenshot_dir)
    end

    it "sanitizes special characters in query" do
      path = screenshot.build_path(action: :search, query: "hello/world!!!", provider: :google)
      basename = File.basename(path)

      expect(basename).to include("hello-world")
      expect(basename).not_to include("/")
      expect(basename).not_to include("!")
    end

    it "truncates long queries to 50 chars" do
      long_query = "a" * 100
      path = screenshot.build_path(action: :search, query: long_query, provider: :google)
      basename = File.basename(path)
      query_part = basename.split("_")[2]

      expect(query_part.length).to be <= 50
    end
  end

  describe "#capture" do
    it "takes a full-page screenshot via the browser" do
      expect(browser).to receive(:screenshot).with(path: a_string_ending_with(".png"))

      screenshot.capture(browser, action: :search, query: "test", provider: :google)
    end
  end

  describe "#capture_element" do
    it "takes an element-scoped screenshot via the browser" do
      expect(browser).to receive(:screenshot_element).with(
        path: a_string_ending_with(".png"),
        selector: "#ai-overview"
      )

      screenshot.capture_element(
        browser,
        selector: "#ai-overview",
        action: :ai_overview,
        query: "turing machine",
        provider: :google
      )
    end
  end
end
