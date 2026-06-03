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

      results = provider.search(browser, 'turing machine')

      expect(results[:provider]).to eq(:google)
      expect(results[:results_count]).to eq(3)
      expect(results[:has_results]).to be true
      expect(results[:ai_overview_present]).to be false
      expect(results[:ai_overview_text]).to be_nil
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
    context 'when AI overview is present' do
      before do
        allow(browser).to receive(:at_css)
          .with('div[data-attrid="kc:/search/ai_overview"]')
          .and_return(double(inner_text: 'An AI overview about Turing machines.'))
      end

      it 'returns true' do
        expect(provider.ai_overview?(browser)).to be true
      end
    end

    context 'when AI overview is absent' do
      before do
        allow(browser).to receive(:at_css).and_return(nil)
        allow(browser).to receive(:evaluate).with(
          a_string_including('document.body.innerText')
        ).and_return(false)
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
          .with('div[data-attrid="kc:/search/ai_overview"]')
          .and_return(overview_element)
      end

      it 'returns the inner text' do
        expect(provider.ai_overview_text(browser)).to eq('A Turing machine is a mathematical model.')
      end
    end

    context 'when AI overview is absent' do
      before do
        allow(browser).to receive(:at_css).and_return(nil)
        allow(browser).to receive(:evaluate).with(
          a_string_including('document.body.innerText')
        ).and_return(nil)
      end

      it 'returns nil' do
        expect(provider.ai_overview_text(browser)).to be_nil
      end
    end
  end
end
