require "spec_helper"

RSpec.describe SGE::Parser::Browser do
  let(:browser) { described_class.new }
  let(:ferrum_browser) { instance_double(Ferrum::Browser) }
  let(:ferrum_page) { instance_double(Ferrum::Page) }

  before do
    allow(Ferrum::Browser).to receive(:new).and_return(ferrum_browser)
    allow(ferrum_browser).to receive(:page).and_return(ferrum_page)
    allow(ferrum_page).to receive(:command)
    allow(ferrum_browser).to receive(:go_to)
    allow(ferrum_browser).to receive(:quit)
    allow(ferrum_browser).to receive(:screenshot)
  end

  describe "#start" do
    it "initializes Ferrum with default options" do
      expect(Ferrum::Browser).to receive(:new).with(
        headless: true,
        window_size: [1920, 1080],
        browser_options: hash_including("disable-blink-features" => "AutomationControlled")
      ).and_return(ferrum_browser)

      browser.start
    end

    it "injects stealth script via Page.addScriptToEvaluateOnNewDocument" do
      expect(ferrum_page).to receive(:command).with(
        "Page.addScriptToEvaluateOnNewDocument",
        hash_including(source: a_string_including("webdriver"))
      )

      browser.start
    end
  end

  describe "#stop" do
    it "quits the browser" do
      browser.start
      expect(ferrum_browser).to receive(:quit)

      browser.stop
    end
  end

  describe "#go_to" do
    it "navigates to the given URL" do
      browser.start
      expect(ferrum_browser).to receive(:go_to).with("https://example.com")

      browser.go_to("https://example.com")
    end
  end

  describe "#screenshot" do
    it "delegates to the underlying browser" do
      browser.start
      expect(ferrum_browser).to receive(:screenshot).with(path: "test.png")

      browser.screenshot(path: "test.png")
    end
  end

  describe "#screenshot_element" do
    it "screenshots a specific CSS selector" do
      browser.start
      expect(ferrum_browser).to receive(:screenshot).with(
        path: "ai_overview.png",
        selector: "#ai-overview"
      )

      browser.screenshot_element(path: "ai_overview.png", selector: "#ai-overview")
    end
  end
end
