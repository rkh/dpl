require 'digest/sha1'
require 'open-uri'

module DPL
  class Provider
    class GAE < Provider
      experimental 'Google App Engine'

      # https://developers.google.com/appengine/downloads
      GAE_VERSION='1.9.6'
      GAE_ZIP_FILE="google_appengine_#{GAE_VERSION}.zip"
      SHA1SUM='888a6687d868ac37f973ea2fb986931338a1c040'
      BASE_DIR=Dir.pwd
      GAE_DIR=File.join(BASE_DIR, 'google_appengine')
      APPCFG_BIN=File.join(GAE_DIR, 'appcfg.py')

      def self.install_sdk
        requires 'rubyzip', :load => 'zip'
        $stderr.puts "Setting up Google App Engine SDK"

        Dir.chdir(BASE_DIR) do
          unless File.exists? GAE_ZIP_FILE
            $stderr.puts "Downloading Google App Engine SDK"
            File.open(GAE_ZIP_FILE, "wb") do |dest|
              open("https://storage.googleapis.com/appengine-sdks/featured/#{GAE_ZIP_FILE}", "rb") do |src|
                dest.write(src.read)
              end
            end
          end
          sha1sum = Digest::SHA1.hexdigest(File.read(GAE_ZIP_FILE))
          unless sha1sum == SHA1SUM
            raise "Checksum did not match for #{GAE_ZIP_FILE}"
          end

          unless File.directory? 'google_appengine'
            $stderr.puts "Extracting Google App Engine SDK archive"
            Zip::File.open(GAE_ZIP_FILE) do |file|
              file.each do |entry|
                entry.extract entry.name
              end
            end
          end
        end
      end

      install_sdk

      def needs_key?
        false
      end

      def check_auth
      end

      def app_dir
        options[:app_dir] || ENV['TRAVIS_BUILD_DIR'] || Dir.pwd
      end

      def push_app
        context.shell "#{APPCFG_BIN} --oauth2_refresh_token=#{options[:oauth_refresh_token]} #{app_dir}"
      end
    end
  end
end