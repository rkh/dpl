module Dpl
  module Providers
    class Pages < Provider
      status :alpha

      full_name 'GitHub Pages'

      description sq(<<-str)
        tbd
      str

      gem 'octokit', '~> 4.14.0'
      gem 'public_suffix', '~> 3.0.3'

      opt '--github_token TOKEN', 'GitHub oauth token with repo permission', required: true, secret: true
      opt '--repo SLUG', 'Repo slug', default: :repo_slug
      opt '--target_branch BRANCH', 'Branch to push force to', default: 'gh-pages'
      opt '--keep_history', 'Create incremental commit instead of doing push force', default: true
      opt '--allow_empty_commit', 'Allow an empty commit to be created', requires: :keep_history
      opt '--committer_from_gh', 'Use the token\'s owner name and email for commit. Overrides the email and name options'
      opt '--verbose', 'Be verbose about the deploy process'
      opt '--local_dir DIR', 'Directory to push to GitHub Pages', default: '.'
      opt '--fqdn FQDN', 'Writes your website\'s domain name to the CNAME file'
      opt '--project_name NAME', 'Used in the commit message only (defaults to fqdn or the current repo slug)'
      opt '--email EMAIL', 'Committer email', default: 'deploy@travis-ci.org'
      opt '--name NAME', 'Committer name', default: 'Deploy Bot'
      # what is the purpose of this file in the first place? a file name with
      # spaces seems highly irregular, but this has been there from the start
      # https://github.com/travis-ci/dpl/commit/58f6c7dd4f0fd49df2e93a8495fd01c7784d4f58#diff-cc5438ae072229825b07abf38951a912R47
      opt '--deployment_file', 'Enable creation of a deployment-info file'
      # not mentioned in the readme
      opt '--github_url URL', default: 'github.com'
      # how about the octokit options?

      needs :git

      msgs login:               'Logged in as %s (%s)',
           invalid_token:       'The provided GitHub token is invalid (error: %s)',
           insufficient_scopes: 'Dpl does not have permission to access %{url} using the provided GitHub token. Please make sure the token have the repo or public_repo scope.',
           deploy:              'Deploying branch %{target_branch} to %{github_url}',
           keep_history:        'The deployment is configured to preserve the target branch if it exists on remote.',
           work_dir:            'Using temporary work directory %{work_dir}',
           committer_from_gh:   'The repo is configured to use committer user and email.',
           setup_dir:           'The source dir for deployment is %s',
           git_clone:           'Cloning the branch %{target_branch} from the remote repo',
           git_init:            'Initializing local git repo in %{cwd}',
           git_checkout:        'Checking out orphan branch %{target_branch}',
           copy_files:          'Copying %{src_dir} contents to %{work_dir}',
           git_config:          'Configuring git committer to be %{committer_name} <%{committer_email}>',
           git_commit:          'Preparing to deploy %{target_branch} branch to gh-pages',
           git_push:            'Pushing to %{url}'

      cmds git_clone:           'git clone --quiet --branch="%{target_branch}" --depth=1 "%{url_with_token}" . > /dev/null 2>&1',
           git_init:            'git init .',
           git_checkout:        'git checkout --orphan "%{target_branch}"',
           copy_files:          'rsync -rl --exclude .git --delete "%{src_dir}/" .',
           git_config_email:    'git config user.email "%{committer_email}"',
           git_config_name:     'git config user.name "%{committer_name}"',
           deployment_file:     'touch "deployed at %{now} by %{committer_name}"',
           cname:               'echo "%{fqdn}" > CNAME',
           git_add:             'git add -A .',
           git_commit:          'git commit%{git_commit_opts} -qm "Deploy %{project_name} to %{url}:%{target_branch}"',
           git_show:            'git show --stat-count=10 HEAD',
           git_push:            'git push%{git_push_opts} --quiet "%{url_with_token}" "%{target_branch}":"%{target_branch}" > /dev/null 2>&1'

      errs copy_files:          'Failed to copy %{src_dir}.',
           git_init:            'Failed to create new git repo',
           git_checkout:        'Failed to create the orphan branch',
           git_push:            'Failed to push the build to %{url}:%{target_branch}'

      def login
        user.login
        info :login, user.login, user.name
        error :insufficient_scopes unless sufficient_scopes?
      rescue Octokit::Unauthorized => e
        error :invalid_token, e.message
      end

      def setup
        info :setup_dir, src_dir
        info :committer_from_gh if committer_from_gh?
      end

      def prepare
        info :deploy
        info :keep_history if keep_history?
        debug :work_dir
        @cwd = Dir.pwd
        Dir.chdir(work_dir)
      end

      def deploy
        git_clone? ? git_clone : git_init
        copy_files
        git_config
        git_commit
        git_push
        git_status if verbose?
      end

      def finish
        Dir.chdir(@cwd) if @cwd
      end

      def git_clone?
        keep_history? && git_branch_exists?
      end

      def git_clone
        info :git_clone
        shell :git_clone, echo: false
      end

      def git_init
        info :git_init
        shell :git_init
        info :git_checkout
        shell :git_checkout
      end

      def copy_files
        info :copy_files
        shell :copy_files
      end

      def git_config
        info :git_config
        shell :git_config_name, echo: false
        shell :git_config_email, echo: false
      end

      def git_commit
        info :git_commit
        shell :deployment_file if deployment_file?
        shell :cname if fqdn?
        shell :git_add
        shell :git_commit
        shell :git_show
      end

      def git_push
        info :git_push
        shell :git_push, echo: false
      end

      def git_status
        shell 'git status'
      end

      def git_branch_exists?
        git_ls_remote?(url_with_token, target_branch)
      end

      def git_commit_opts
        ' --allow-empty' if allow_empty_commit?
      end

      def git_push_opts
        ' --force' unless keep_history?
      end

      def committer_name
        committer_from_gh? ? user.name || name : name
      end

      def committer_email
        committer_from_gh? ? user.email || email : email
      end

      def project_name
        super || fqdn || repo_slug
      end

      def name
        "#{super} (from Travis CI)"
      end

      def sufficient_scopes?
        api.scopes.include?('public_repo') || api.scopes.include?('repo')
      end

      def url_with_token
        "https://#{github_token}@#{url}"
      end

      def url
        "#{github_url}/#{slug}.git"
      end

      def slug
        repo || repo_slug
      end

      def user
        @user ||= api.user
      end

      def src_dir
        @src_dir ||= File.absolute_path(local_dir)
      end

      def work_dir
        @work_dir ||= tmp_dir
      end

      def api
        @api ||= Octokit::Client.new(access_token: github_token, api_endpoint: api_endpoint)
      end

      def api_endpoint
        github_url == 'github.com' ? "https://api.github.com/" : "https://#{github_url}/api/v3/"
      end

      def cwd
        Dir.pwd
      end

      def now
        Time.now
      end

      def debug(*args)
        info *args if verbose?
      end
    end
  end
end
