module Dpl
  class Provider < Cl::Cmd
    class Status < Struct.new(:provider, :status, :info)
      STATUS = %i(dev alpha beta stable deprecated)

      MSG = {
        dev:        'Support for deployments to %s is in development',
        alpha:      'Support for deployments to %s is in alpha',
        beta:       'Support for deployments to %s is in beta',
        deprecated: 'Support for deployments to %s is deprecated',
        pre_stable: 'Please see here: %s'
      }

      URL = 'https://github.com/travis-ci/dpl/#maturity-levels'

      def initialize(provider, status, info)
        unknown!(status) unless known?(status)
        super
      end

      def announce?
        !stable?
      end

      def msg
        msg = "#{MSG[status] % name}"
        msg << "(#{info})" if info
        msg << ". #{MSG[:pre_stable] % URL}" if pre_stable?
        "\n#{msg}\n"
      end

      private

        def name
          provider.full_name
        end

        def pre_stable?
          STATUS.index(status) < STATUS.index(:stable)
        end

        def stable?
          status == :stable
        end

        def deprecated?
          status == :deprecated
        end

        def known?(status)
          STATUS.include?(status)
        end

        def unknown!(status)
          raise "Unknown status: #{status.inspect}. Known statuses are: #{STATUS.map(&:inspect).join(', ')}"
        end
    end
  end
end
