require "base64"

module DPL
  class Provider
    class Pages < Provider
      """Implements Github Pages deployment

      Options:
        - repo [optional, for pushed to other repos]
        - github-token [this or deploy-key required]
        - deploy-key [this or github-token required]
        - github-url [optional, defaults to github.com]
        - target-branch [optional, defaults to gh-pages]
        - local-dir [optional, defaults to `pwd`]
        - fqdn [optional]
        - project-name [optional, defaults to fqdn or repo slug]
        - email [optional, defaults to deploy@travis-ci.org]
        - name [optional, defaults to Deployment Bot]
      """

      require 'tmpdir'

      experimental 'GitHub Pages'

      def initialize(context, options)
        super

        @build_dir = options[:local_dir] || '.'
        @project_name = options[:project_name] || fqdn || slug
        @target_branch = options[:target_branch] || 'gh-pages'

        @gh_fqdn = fqdn
        @gh_url = options[:github_url] || 'github.com'
        @gh_token = options[:github_token]
        @gh_deploy_key = options[:deploy_key]
        unless @gh_token || @gh_deploy_key
          raise(Error, "must specify github-token or deploy-key")
        end

        @gh_email = options[:email] || 'deploy@travis-ci.org'
        @gh_name = "#{options[:name] || 'Deployment Bot'} (from Travis CI)"

        @gh_ref = "#{@gh_url}/#{slug}.git"
      end

      def fqdn
        options.fetch(:fqdn) { nil }
      end

      def slug
        options.fetch(:repo) { context.env['TRAVIS_REPO_SLUG'] }
      end

      def check_auth
      end

      def needs_key?
        # Provider's generic support for keys is about provisioning and
        # deprovisioning them, while this provider needs to install a key
        # provided by the caller.
        false
      end

      def github_deploy
        context.shell 'rm -rf .git > /dev/null 2>&1'
        context.shell "touch \"deployed at `date` by #{@gh_name}\""
        context.shell 'git init' or raise 'Could not create new git repo'
        context.shell "git config user.email '#{@gh_email}'"
        context.shell "git config user.name '#{@gh_name}'"
        context.shell "echo '#{@gh_fqdn}' > CNAME" if @gh_fqdn
        context.shell 'git add .'
        context.shell "FILES=\"`git commit -m 'Deploy #{@project_name} to #{@gh_ref}:#{@target_branch}' | tail`\"; echo \"$FILES\"; echo \"$FILES\" | [ `wc -l` -lt 10 ] || echo '...'"
        if @gh_token
          target_repo = "https://#{@gh_token}@#{@gh_ref}"
        else
          # Depend on the key set up in push_app.
          target_repo = "git@github.com:#{slug}.git"
        end
        context.shell "git push --force --quiet '#{target_repo}' master:#{@target_branch}"
      end

      def push_app
        Dir.mktmpdir {|gitdir|
          if @gh_deploy_key
            # Install the key.
            File.open("#{gitdir}/deploykey", "w", 0600) {|file|
              file.write Base64.decode64(@gh_deploy_key)
            }
            setup_git_ssh("#{gitdir}/git-ssh", "#{gitdir}/deploykey")
          end
          Dir.mktmpdir {|tmpdir|
            FileUtils.cp_r("#{@build_dir}/.", tmpdir)
            FileUtils.cd(tmpdir, :verbose => true) do
              unless github_deploy
                error "Couldn't push the build to #{@gh_ref}:#{@target_branch}"
              end
            end
          }
        }
      end

    end
  end
end
