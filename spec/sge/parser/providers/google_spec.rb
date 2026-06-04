require 'spec_helper'

RSpec.describe SGE::Parser::Providers::Google do
  let(:provider) { described_class.new }
  let(:browser) { instance_double(SGE::Parser::Browser) }

  before do
    allow(browser).to receive(:human_search)
    allow(browser).to receive(:title).and_return('turing machine - Google Search')
    allow(browser).to receive(:css).with('h3').and_return([1, 2, 3])
    allow(browser).to receive(:css).with('#search').and_return([1])
    allow(browser).to receive(:at_css).and_return(nil)
    allow(browser).to receive(:evaluate).and_return('https://www.google.com/search?q=turing+machine')
  end

  describe '#search' do
    it 'uses human_search to navigate' do
      expect(browser).to receive(:human_search).with('turing machine')
      provider.search(browser, 'turing machine')
    end

    it 'returns parsed results' do
      allow(provider).to receive(:ai_overview?).and_return(false)
      allow(provider).to receive(:ai_overview_text).and_return(nil)
      allow(provider).to receive(:ai_overview_references).and_return([])

      results = provider.search(browser, 'turing machine')

      expect(results[:provider]).to eq(:google)
      expect(results[:results_count]).to eq(3)
      expect(results[:has_results]).to be true
      expect(results[:ai_overview_present]).to be false
      expect(results[:ai_overview_text]).to be_nil
      expect(results[:ai_overview_references]).to eq([])
    end

    it 'raises CaptchaError when CAPTCHA is detected' do
      allow(browser).to receive(:at_css).with('form[action="/sorry"]').and_return(double)

      expect do
        provider.search(browser, 'turing machine')
      end.to raise_error(SGE::Parser::CaptchaError)
    end

    it 'raises CaptchaError when title contains unusual traffic' do
      allow(browser).to receive(:title).and_return('unusual traffic')
      allow(browser).to receive(:at_css).with('form[action="/sorry"]').and_return(nil)
      allow(browser).to receive(:at_css).with('#captcha').and_return(nil)

      expect do
        provider.search(browser, 'turing machine')
      end.to raise_error(SGE::Parser::CaptchaError)
    end
  end

  describe '#ai_overview?' do
    context 'when AI overview element matches via CSS selector' do
      before do
        allow(browser).to receive(:at_css)
          .with('div[data-attrid*="ai_overview"]')
          .and_return(double(inner_text: 'An AI overview about Turing machines.'))
      end

      it 'returns true' do
        expect(provider.ai_overview?(browser)).to be true
      end
    end

    context 'when AI overview is found via heading text fallback' do
      before do
        # All CSS selectors return nil
        allow(browser).to receive(:at_css).and_return(nil)
        # Heading fallback finds the element
        allow(browser).to receive(:evaluate).and_return('div[data-sge-ai-overview="true"]')
        allow(browser).to receive(:at_css)
          .with('div[data-sge-ai-overview="true"]')
          .and_return(double(inner_text: 'An AI overview about Turing machines.'))
      end

      it 'returns true when heading text fallback succeeds' do
        custom_provider = described_class.new(ai_overview_selector: 'div[data-sge-ai-overview="true"]')
        allow(browser).to receive(:at_css)
          .with('div[data-sge-ai-overview="true"]')
          .and_return(double(inner_text: 'An AI overview about Turing machines.'))

        expect(custom_provider.ai_overview?(browser)).to be true
      end
    end

    context 'when AI overview is absent' do
      before do
        allow(browser).to receive(:at_css).and_return(nil)
        allow(browser).to receive(:evaluate).and_return(nil)
      end

      it 'returns false' do
        expect(provider.ai_overview?(browser)).to be false
      end
    end
  end

  describe '#ai_overview_text' do
    context 'when AI overview is present' do
      let(:overview_element) { double(inner_text: 'A Turing machine is a mathematical model.') }

      before do
        allow(browser).to receive(:at_css)
          .with('div[data-attrid*="ai_overview"]')
          .and_return(overview_element)
      end

      it 'returns the inner text' do
        expect(provider.ai_overview_text(browser)).to eq('A Turing machine is a mathematical model.')
      end
    end

    context 'when AI overview is absent' do
      before do
        allow(browser).to receive(:at_css).and_return(nil)
        allow(browser).to receive(:evaluate).and_return(nil)
      end

      it 'returns nil' do
        expect(provider.ai_overview_text(browser)).to be_nil
      end
    end
  end

  describe '#ai_overview_references' do
    context 'when AI overview is present with reference links' do
      let(:overview_element) { double(inner_text: 'Some text') }

      before do
        allow(browser).to receive(:at_css)
          .with('div[data-attrid*="ai_overview"]')
          .and_return(overview_element)
        allow(browser).to receive(:at_css)
          .with('div[data-attrid="kc:/search/ai_overview"]')
          .and_return(overview_element)
        allow(browser).to receive(:evaluate).and_return([
          { index: 1, text: 'Source 1', url: 'https://example.com/1' },
          { index: 2, text: 'Source 2', url: 'https://example.com/2' }
        ])
      end

      it 'returns an array of reference link hashes' do
        refs = provider.ai_overview_references(browser)
        expect(refs).to be_an(Array)
        expect(refs.length).to eq(2)
      end
    end

    context 'when AI overview is absent' do
      before do
        allow(browser).to receive(:at_css).and_return(nil)
        allow(browser).to receive(:evaluate).and_return(nil)
      end

      it 'returns an empty array' do
        expect(provider.ai_overview_references(browser)).to eq([])
      end
    end
  end

  describe '#diagnose_ai_overview' do
    before do
      allow(browser).to receive(:at_css).and_return(nil)
      allow(browser).to receive(:evaluate).and_return(nil, [], nil)
    end

    it 'returns a hash with diagnostic information' do
      result = provider.diagnose_ai_overview(browser)

      expect(result).to have_key(:configured_selector)
      expect(result).to have_key(:fallback_selectors)
      expect(result).to have_key(:selector_matches)
      expect(result).to have_key(:heading_found)
      expect(result).to have_key(:attrid_values)
      expect(result).to have_key(:heading_containers)
    end

    it 'includes all fallback selectors in matches' do
      result = provider.diagnose_ai_overview(browser)

      expect(result[:selector_matches]).to be_an(Array)
      expect(result[:selector_matches].length).to eq(described_class::AI_OVERVIEW_SELECTORS.length)
    end
  end

  describe 'custom selector override' do
    let(:custom_selector) { 'div.custom-ai-overview' }
    let(:provider_with_custom) { described_class.new(ai_overview_selector: custom_selector) }

    it 'uses the custom selector first' do
      expect(browser).to receive(:at_css).with(custom_selector).and_return(nil)
      # Then falls through to default selectors
      expect(browser).to receive(:at_css).with('div[data-attrid*="ai_overview"]').and_return(nil)
      expect(browser).to receive(:at_css).with('div[data-attrid="kc:/search/ai_overview"]').and_return(nil)
      expect(browser).to receive(:at_css).with('div[data-attrid="kc:/search/ai_overview:"]').and_return(nil)
      expect(browser).to receive(:evaluate).and_return(nil)

      provider_with_custom.ai_overview?(browser)
    end
  end
end
