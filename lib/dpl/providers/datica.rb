module Dpl
  module Providers
    class Datica < Provider
      register :datica, :catalyze

      description sq(<<-str)
        tbd
      str

      env :datica, :catalyze

      opt '--target TARGET', 'The git remote repository to deploy to', required: true
      opt '--path PATH', 'Path to files to deploy', default: '.'

      needs :git

      cmds checkout: 'git checkout HEAD',
           add:      'git add %{path} --all --force',
           commit:   'git commit -m "%{message}" --quiet',
           push:     'git push --force %{target} HEAD:master'

      msgs commit:   'Committing build files for deployment',
           deploy:   'Deploying to Datica: %{target}'

      def setup
        commit unless cleanup?
      end

      def deploy
        info :deploy
        shell :push
      end

      private

        def commit
          info :commit
          shell :checkout
          shell :add
          shell :commit
        end

        def message
          vars.empty? ? 'Local build' : 'Build #%s (%s) of %s@%s' % vars
        end

        VARS = %w(
          TRAVIS_BUILD_NUMBER
          TRAVIS_COMMIT
          TRAVIS_REPO_SLUG
          TRAVIS_BRANCH
        )

        def vars
          @vars ||= ENV.values_at(*VARS).compact
        end
    end
  end
end
