require 'dpl/error'
require 'fileutils'

module DPL
  class Provider
    include FileUtils

    autoload :Heroku,       'dpl/provider/heroku'
    autoload :EngineYard,   'dpl/provider/engine_yard'
    autoload :DotCloud,     'dpl/provider/dot_cloud'
    autoload :Nodejitsu,    'dpl/provider/nodejitsu'
    autoload :Openshift,    'dpl/provider/openshift'
    autoload :RubyGems,     'dpl/provider/rubygems'
    autoload :CloudControl, 'dpl/provider/cloudcontrol'
    autoload :CloudFoundry, 'dpl/provider/cloud_foundry'

    def self.new(context, options)
      return super if self < Provider

      context.fold("Installing deploy dependencies") do
        name = super.option(:provider).to_s.downcase.gsub(/[^a-z]/, '')
        raise Error, 'could not find provider %p' % options[:provider] unless name = constants.detect { |c| c.to_s.downcase == name }
        const_get(name).new(context, options)
      end
    end

    def self.experimental(name)
      puts "", "!!! #{name} support is experimental !!!", ""
    end

    def self.requires(name, options = {})
      version = options[:version] || '> 0'
      load    = options[:load]    || name
      gem(name, version)
    rescue LoadError
      context.shell("gem install %s -v %p" % [name, version])
      Gem.clear_paths
    ensure
      require load
    end

    def self.context
      self
    end

    def self.shell(command)
      system(command)
    end

    def self.pip(name, command = name)
      context.shell "sudo pip install #{name}" if `which #{command}`.chop.empty?
    end

    def self.npm_g(name, command = name)
      context.shell "npm install -g #{name}" if `which #{command}`.chop.empty?
    end

    attr_reader :context, :options

    def initialize(context, options)
      @context, @options = context, options
    end

    def option(name, *alternatives)
      options.fetch(name) do
        alternatives.any? ? option(*alternatives) : raise(Error, "missing #{name}")
      end
    end

    def deploy
      rm_rf ".dpl"
      mkdir_p ".dpl"

      context.fold("Preparing deploy") do
        check_auth
        check_app

        if needs_key?
          create_key(".dpl/id_rsa")
          setup_key(".dpl/id_rsa.pub")
          setup_git_ssh(".dpl/git-ssh", ".dpl/id_rsa")
        end

        cleanup
      end

      context.fold("Deploying application") { push_app }

      Array(options[:run]).each do |command|
        if command == 'restart'
          context.fold("Restarting application") { restart }
        else
          context.fold("Running %p" % command) { run(command) }
        end
      end
    ensure
      if needs_key?
        remove_key rescue nil
      end
    end

    def sha
      @sha ||= ENV['TRAVIS_COMMIT'] || `git rev-parse HEAD`.strip
    end

    def cleanup
      return if options[:skip_cleanup]
      context.shell "git reset --hard #{sha}"
      context.shell "git clean -dffqx -e .dpl"
    end

    def needs_key?
      true
    end

    def check_app
    end

    def create_key(file)
      context.shell "ssh-keygen -t rsa -N \"\" -C #{option(:key_name)} -f #{file}"
    end

    def setup_git_ssh(path, key_path)
      key_path = File.expand_path(key_path)
      path     = File.expand_path(path)

      File.open(path, 'w') do |file|
        file.write "#!/bin/sh\n"
        file.write "exec ssh -o StrictHostKeychecking=no -o CheckHostIP=no -o UserKnownHostsFile=/dev/null -i #{key_path} -- \"$@\"\n"
      end

      chmod(0740, path)
      ENV['GIT_SSH'] = path
    end

    def log(message)
      $stderr.puts(message)
    end

    def run(command)
      error "running commands not supported"
    end

    def error(message)
      raise Error, message
    end
  end
end
