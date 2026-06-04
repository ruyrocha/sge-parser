require 'spec_helper'

RSpec.describe SGE::Parser do
  describe '.configure' do
    it 'yields the configuration object' do
      described_class.configure do |config|
        config.screenshot_dir = '/tmp/test-screenshots'
      end

      expect(described_class.config.screenshot_dir).to eq('/tmp/test-screenshots')
    end
  end

  describe '.search' do
    let(:browser) { instance_double(SGE::Parser::Browser) }
    let(:provider) { instance_double(SGE::Parser::Providers::Google, ai_overview_selector: 'div[data-attrid*="ai_overview"]') }
    let(:screenshot_manager) { instance_double(SGE::Parser::Screenshot) }

    before do
      allow(SGE::Parser::Browser).to receive(:new).and_return(browser)
      allow(SGE::Parser::Providers).to receive(:build).and_return(provider)
      allow(SGE::Parser::Screenshot).to receive(:new).and_return(screenshot_manager)

      allow(browser).to receive(:start)
      allow(browser).to receive(:stop)
      allow(browser).to receive(:warm_up)
      allow(browser).to receive(:at_css).and_return(nil)
      allow(screenshot_manager).to receive(:capture).and_return('screenshots/test.png')
      allow(screenshot_manager).to receive(:capture_element).and_return('screenshots/ai_overview.png')
    end

    it 'delegates search to the provider' do
      expect(provider).to receive(:search).with(
        browser, 'ruby gems'
      ).and_return({ provider: :google, results_count: 5 })

      described_class.search('ruby gems')
    end

    it 'returns results with screenshot path when screenshot is true' do
      allow(provider).to receive(:search).and_return(
        { provider: :google, results_count: 5, ai_overview_present: false, ai_overview_selector: 'div[data-attrid*="ai_overview"]' }
      )

      results = described_class.search('ruby gems', screenshot: true)
      expect(results).to have_key(:screenshot)
      expect(results[:screenshot]).to eq('screenshots/test.png')
    end

    it 'does not attach screenshot when disabled' do
      allow(provider).to receive(:search).and_return(
        { provider: :google, results_count: 5, ai_overview_present: false, ai_overview_selector: 'div[data-attrid*="ai_overview"]' }
      )
      expect(screenshot_manager).not_to receive(:capture)

      results = described_class.search('ruby gems', screenshot: false)
      expect(results).not_to have_key(:screenshot)
    end

    it 'ensures the browser is stopped' do
      allow(provider).to receive(:search).and_return(
        { provider: :google, results_count: 5, ai_overview_present: false, ai_overview_selector: 'div[data-attrid*="ai_overview"]' }
      )
      expect(browser).to receive(:stop)

      described_class.search('ruby gems')
    end

    it 'calls warm_up when warm_up option is true' do
      allow(provider).to receive(:search).and_return(
        { provider: :google, results_count: 5, ai_overview_present: false, ai_overview_selector: 'div[data-attrid*="ai_overview"]' }
      )
      expect(browser).to receive(:warm_up)

      described_class.search('ruby gems', warm_up: true)
    end

    context 'when AI overview is present' do
      before do
        allow(provider).to receive(:search).and_return(
          {
            provider: :google,
            results_count: 5,
            ai_overview_present: true,
            ai_overview_selector: 'div[data-attrid*="ai_overview"]'
          }
        )
        allow(browser).to receive(:at_css).with('div[data-attrid*="ai_overview"]').and_return(double)
      end

      it 'captures an AI overview element screenshot' do
        expect(screenshot_manager).to receive(:capture_element).with(
          browser,
          selector: 'div[data-attrid*="ai_overview"]',
          action: :ai_overview,
          query: 'turing machine',
          provider: :google
        ).and_return('screenshots/ai_overview.png')

        results = described_class.search('turing machine', screenshot: true)
        expect(results).to have_key(:ai_overview_screenshot)
        expect(results[:ai_overview_screenshot]).to eq('screenshots/ai_overview.png')
      end
    end

    context 'when AI overview is absent' do
      before do
        allow(provider).to receive(:search).and_return(
          {
            provider: :google,
            results_count: 5,
            ai_overview_present: false,
            ai_overview_selector: 'div[data-attrid*="ai_overview"]'
          }
        )
      end

      it 'does not capture an AI overview screenshot' do
        expect(screenshot_manager).not_to receive(:capture_element)

        results = described_class.search('turing machine', screenshot: true)
        expect(results).not_to have_key(:ai_overview_screenshot)
      end
    end
  end
end
