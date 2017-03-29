module DPL
  class Provider
    class TestFairy < Provider

      requires "multipart-post", load: 'net/http/post/multipart', version: '2.0.0'

      require "net/http"
      require 'net/http/post/multipart'
      require 'json'
      require 'tempfile'


      VERSION = "0.1"
      TAG = "-TestFairy-"
      SERVER = "https://upload.testfairy.com"
      UPLOAD_URL_PATH = "/api/upload";
      UPLOAD_SIGNED_URL_PATH = "/api/upload-signed";

      def check_auth
        if android?
          storepassToPrint = option(:storepass).clone
          aliasToPrint = option(:alias).clone
          puts "keystore-file = #{option(:keystore_file)} storepass = #{storepassToPrint.sub! storepassToPrint[1..-2], '****'} alias = #{aliasToPrint.sub! aliasToPrint[1..-2], '****'}"
        end
        puts "api-key = #{option(:api_key).gsub(/[123456789]/, '*')} symbols-file = #{options[:symbols_file]}"
      end

      def needs_key?
        false
      end

      def push_app
        puts "push_app #{TAG}"
        response = upload_app
        if android?
          puts response['instrumented_url']
          instrumentedFile = download_from_url response['instrumented_url']
          signedApk = signing_apk instrumentedFile
          response = upload_signed_apk signedApk
        end
        puts "Upload success!, check your build on #{response['build_url']}"
      end

      def android?
        option(:app_file).include? "apk"
      end


      private

      def signing_apk(instrumentedFile)
        signed = Tempfile.new(['instrumented-signed', '.apk'])
        zipOutput = %x[#{zip_path} -qd #{instrumentedFile} META-INF/*]
        if zipOutput.include? 'error'
          raise Error, zipOutput
        end

        jarSignerOutput = %x[#{jarsigner_path} -keystore #{option(:keystore_file)} -storepass #{option(:storepass)} -digestalg SHA1 -sigalg MD5withRSA #{instrumentedFile} #{option(:alias)}]
        if jarSignerOutput.include? 'error'
          raise Error, jarSignerOutput
        end

        verifyOutput = %x[#{jarsigner_path} -verify  #{instrumentedFile}]
        if !verifyOutput.include? 'jar verified'
          raise Error, verifyOutput
        end

        zipAlignOutput = %x[#{zipalign_path} -f 4 #{instrumentedFile} #{signed.path}]

        puts "signing Apk finished: #{signed.path()}  (file size:#{File.size(signed.path())} )"
        signed.path()
      end

      def download_from_url(url)
        puts "downloading from #{url} "
        url = "#{url}?api_key=#{option(:api_key)}"
        uri = URI.parse(url)
        instrumentedFile = Net::HTTP.start(uri.host, uri.port) do |http|
          resp = http.get "#{uri.path}?#{uri.query}"
          if resp.code == "302"
            resp = Net::HTTP.get_response(URI.parse(resp.header['location']))
          end
          file = Tempfile.new(['instrumented', '.apk'])
          file.write(resp.body)
          file.flush
          file
        end
        puts "Done #{instrumentedFile.path()}  (file size:#{File.size(instrumentedFile.path())} )"
        instrumentedFile.path()
      end

      def upload_app
        uploadUrl = SERVER + UPLOAD_URL_PATH
        params = get_params
        post uploadUrl, params
      end

      def upload_signed_apk apkPath
        uploadSignedUrl = SERVER + UPLOAD_SIGNED_URL_PATH

        params = {"api_key" => "#{option(:api_key)}"}
        add_file_param params , 'apk_file', apkPath
        add_file_param params, 'symbols_file', options[:symbols_file]
        add_param params, 'testers-groups', options[:testers_groups]
        add_boolean_param params, 'notify', options[:notify]
        add_boolean_param params, 'auto-update', options[:auto_update]

        post uploadSignedUrl, params
      end

      def post url, params
        puts "Upload parameters = #{get_printable_params params} \nto #{url}"
        uri = URI.parse(url)
        request = Net::HTTP::Post::Multipart.new(uri.path, params, 'User-Agent' => "Travis plugin version=#{VERSION}")
        res = Net::HTTP.start(uri.host, uri.port) do |http|
          http.request(request)
        end
        puts res.body
        resBody = JSON.parse(res.body)
        if (resBody['status'] == 'fail')
          raise Error, resBody['message']
        end
        return resBody
      end

      def get_printable_params params
        paramsToPrint = params.clone
        paramsToPrint['api_key'] = paramsToPrint['api_key'].gsub(/[123456789]/, '*')
        paramsToPrint['apk_file'] = paramsToPrint['apk_file'].path()
        JSON.pretty_generate(paramsToPrint)
      end

      def get_params
        params = {'api_key' => "#{option(:api_key)}"}
        add_file_param params, 'apk_file', option(:app_file)
        add_file_param params, 'symbols_file', options[:symbols_file]
        add_param params, 'video-quality', options[:video_quality]
        add_param params, 'screenshot-interval', options[:screenshot_interval]
        add_param params, 'max-duration', options[:max_duration]
        add_param params, 'testers-groups', options[:testers_groups]
        add_param params, 'advanced-options', options[:advanced_options]
        add_param params, 'metrics', options[:metrics]
        add_boolean_param params, 'data-only-wifi', options[:data_only_wifi]
        add_boolean_param params, 'record-on-background', options[:record_on_background]
        add_boolean_param params, 'video', options[:video]
        add_boolean_param params, 'notify', options[:notify]
        add_boolean_param params, 'icon-watermark', options[:icon_watermark]

        travisCommitRange = context.env.fetch('TRAVIS_COMMIT_RANGE',nil)
        if !travisCommitRange.nil?
          changelog = %x[git log  --pretty=oneline --abbrev-commit #{travisCommitRange}]
          add_param params, 'changelog', changelog
        end
        params
      end

      def add_file_param params, fileName, filePath
        if (!filePath.nil? && !filePath.empty?)
          params[fileName] = UploadIO.new(File.new(filePath), "", filePath.split("/").last)
        end
      end

      def add_param params, paramName, param
        if (!param.nil? && !param.empty?)
          params[paramName] = param
        end
      end

      def add_boolean_param params, paramName, param
        if (!param.nil? && !param.empty?)
          params[paramName] = (param == true) ? "on" : "off"
        end
      end

      def zip_path
        @zip_path ||= %x[which zip].split("\n").first
      end

      def zipalign_path
        android_home_path = context.env.fetch('ANDROID_HOME', '/usr')
        @zipalign_path ||= %x[find -L #{android_home_path} -name zipalign 2>/dev/null].split("\n").first
      end

      def jarsigner_path
        java_home_path = context.env.fetch('JAVA_HOME', '/usr')
        @jarsigner_path ||= %x[find -L #{java_home_path} -name jarsigner 2>/dev/null].split("\n").first
      end
    end
  end
end
