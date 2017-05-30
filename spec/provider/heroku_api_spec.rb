require 'spec_helper'
require 'heroku-api'
require 'dpl/provider/heroku'

describe DPL::Provider::Heroku do
  let(:opts) { {:app => 'example', :key_name => 'key', :api_key => "foo", :strategy => "api"} }
  subject(:provider) do
    described_class.new(DummyContext.new, opts)
  end

  let(:expected_headers) do
    { "User-Agent" => "dpl/#{DPL::VERSION} heroku-rb/#{Heroku::API::VERSION}", "Accept" => "application/vnd.heroku+json; version=3" }
  end

  describe "#ssh" do
    it "doesn't require an ssh key" do
      expect(provider.needs_key?).to eq(false)
    end
  end

  describe "#api" do
    it 'accepts an api key' do
      api = double(:api)
      expect(::Heroku::API).to receive(:new).with(:api_key => "foo", :headers => expected_headers).and_return(api)
      expect(provider.api).to eq(api)
    end

    it 'accepts a user and a password' do
      api = double(:api)
      provider.options.update(:user => "foo", :password => "bar")
      expect(::Heroku::API).to receive(:new).with(:user => "foo", :password => "bar", :headers => expected_headers).and_return(api)
      expect(provider.api).to eq(api)
    end
  end

  describe "#trigger_build" do
    let(:response_body) { {
      "created_at" => "2012-01-01T12:00:00Z",
      "id" => "abc",
      "status" => "pending",
      "output_stream_url" => "http://example.com/stream",
      "updated_at" => "2012-01-01T12:00:00Z",
      "user" => { "id" => "01234567-89ab-cdef-0123-456789abcdef", "email" => "username@example.com" }
    } }

    context "with no verbose option" do
      example do
        expect(provider).to receive(:log).with('triggering new deployment')
        expect(provider).to receive(:get_url).and_return 'http://example.com/source.tgz'
        expect(provider).to receive(:version).and_return 'sha'
        expect(provider).to receive(:post).with(
          :builds, source_blob: {url: 'http://example.com/source.tgz', version: 'sha'}
        ).and_return(response_body)
        expect(provider.context).to receive(:shell).with('curl    http://example.com/stream')
        provider.trigger_build
        expect(provider.build_id).to eq('abc')
      end
    end

    context "with verbose option" do
      let(:opts) { {:app => 'example', :key_name => 'key', :api_key => "foo", :strategy => "api", :verbose => true} }

      example do
        expect(provider).to receive(:log).with('triggering new deployment')
        expect(provider).to receive(:get_url).and_return 'http://example.com/source.tgz'
        expect(provider).to receive(:version).and_return 'sha'
        expect(provider).to receive(:post).with(
          :builds, source_blob: {url: 'http://example.com/source.tgz', version: 'sha'}
        ).and_return(response_body)
        expect(provider.context).to receive(:shell).with('curl -vvv   http://example.com/stream')
        provider.trigger_build
        expect(provider.build_id).to eq('abc')
      end
    end

    context "with ssl_protocol option" do
      let(:opts) { {:app => 'example', :key_name => 'key', :api_key => "foo", :strategy => "api", :verbose => true, :ssl_protocol => 'tlsv1.2'} }

      example do
        expect(provider).to receive(:log).with('triggering new deployment')
        expect(provider).to receive(:get_url).and_return 'http://example.com/source.tgz'
        expect(provider).to receive(:version).and_return 'sha'
        expect(provider).to receive(:post).with(
          :builds, source_blob: {url: 'http://example.com/source.tgz', version: 'sha'}
        ).and_return(response_body)
        expect(provider.context).to receive(:shell).with('curl -vvv --tlsv1.2  http://example.com/stream')
        provider.trigger_build
        expect(provider.build_id).to eq('abc')
      end
    end
  end

  describe "#verify_build" do
    def response_body(status, exit_code)
      {
        "build" => {
          "id" => "01234567-89ab-cdef-0123-456789abcdef",
          "status" => status
        },
        "exit_code" => exit_code
      }
    end

    before do
      allow(provider).to receive(:build_id).and_return('abc')
    end

    context 'when build succeeds' do
      example do
        expect(provider).to receive(:get).with('builds/abc/result').and_return(response_body('succeeded', 0))
        expect{ provider.verify_build }.not_to raise_error
      end
    end

    context 'when build fails' do
      example do
        expect(provider).to receive(:get).with('builds/abc/result').and_return(response_body('failed', 1))
        expect{ provider.verify_build }.to raise_error("deploy failed, build exited with code 1")
      end
    end

    context 'when build is pending, then succeeds' do
      example do
        expect(provider).to receive(:get).with('builds/abc/result').and_return(response_body('pending', nil), response_body('succeeded', 0))
        expect(provider).to receive(:log).with('heroku build still pending')
        expect(provider).to receive(:sleep).with(5) # stub sleep
        expect{ provider.verify_build }.not_to raise_error
      end
    end

  end

end
