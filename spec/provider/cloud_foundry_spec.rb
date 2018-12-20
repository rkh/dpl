require 'spec_helper'
require 'dpl/provider/cloud_foundry'

describe DPL::Provider::CloudFoundry do
  subject :provider do
    described_class.new(DummyContext.new, api: 'api.run.awesome.io', username: 'mallomar',
                        password: 'myreallyawesomepassword',
                        organization: 'myorg',
                        space: 'outer',
                        manifest: 'worker-manifest.yml',
                        skip_ssl_validation: true)
  end


  describe "#check_auth" do
    context 'when basic credentials are provided' do
      example do
        expect(provider.context).to receive(:shell).with('test $(uname) = "Linux" && rel="linux64-binary" || rel="macosx64"; wget "https://cli.run.pivotal.io/stable?release=${rel}&source=github" -qO cf.tgz && tar -zxvf cf.tgz && rm cf.tgz')
        expect(provider.context).to receive(:shell).with('./cf api api.run.awesome.io --skip-ssl-validation')
        expect(provider.context).to receive(:shell).with('./cf login -u mallomar -p myreallyawesomepassword -o \'myorg\' -s \'outer\'')
        provider.check_auth
      end
    end

    context 'when client credentials are provided' do
      subject :provider do
        described_class.new(DummyContext.new, api: 'api.run.awesome.io', client_id: 'craw',
                            client_secret: 'myreallyawesomesecret',
                            organization: 'myorg',
                            space: 'outer',
                            manifest: 'worker-manifest.yml',
                            skip_ssl_validation: true)
      end

      example do
        expect(provider.context).to receive(:shell).with('test $(uname) = "Linux" && rel="linux64-binary" || rel="macosx64"; wget "https://cli.run.pivotal.io/stable?release=${rel}&source=github" -qO cf.tgz && tar -zxvf cf.tgz && rm cf.tgz')
        expect(provider.context).to receive(:shell).with('./cf api api.run.awesome.io --skip-ssl-validation')
        expect(provider.context).to receive(:shell).with('./cf auth craw myreallyawesomesecret --client-credentials')
        expect(provider.context).to receive(:shell).with('./cf target -o \'myorg\' -s \'outer\'')
        provider.check_auth
      end
    end
  end

  describe "#check_app" do
    context 'when the manifest file exists' do
      example do
        File.stub(:exists?).with('worker-manifest.yml').and_return(true)
        expect{provider.check_app}.not_to raise_error
      end
    end

    context 'when the manifest file exists' do
      example do
        File.stub(:exists?).with('worker-manifest.yml').and_return(false)
        expect{provider.check_app}.to raise_error('Application must have a manifest.yml for unattended deployment')
      end
    end
  end

  describe "#needs_key?" do
    example do
      expect(provider.needs_key?).to eq(false)
    end
  end

  describe "#push_cmd" do
    example "with v3 not specified" do
      provider.options.delete(:v3_push)

      expect(provider.push_cmd).to eq("push")
    end

    example "with v3 set to false" do
      provider.options.update(:v3_push => false)

      expect(provider.push_cmd).to eq("push")
    end

    example "with v3 set to true" do
      provider.options.update(:v3_push => true)

      expect(provider.push_cmd).to eq("v3-push")
    end
  end

  describe "#push_app" do
    before do
      allow(provider.context).to receive(:shell).and_return(true)
    end

    example "With manifest" do
      expect(provider.context).to receive(:shell).with('./cf push -f worker-manifest.yml')
      expect(provider.context).to receive(:shell).with('./cf logout')
      provider.push_app
    end

    example "Without manifest" do
      provider.options.update(:manifest => nil)
      expect(provider.context).to receive(:shell).with('./cf push')
      expect(provider.context).to receive(:shell).with('./cf logout')
      provider.push_app
    end

    example 'Failed to push' do
      allow(provider.context).to receive(:shell).and_return(false)

      expect(provider.context).to receive(:shell).with('./cf push -f worker-manifest.yml')
      expect(provider.context).to receive(:shell).with('./cf logout')
      expect{provider.push_app}.to raise_error(DPL::Error, 'Failed to push app')
    end
  end
end
