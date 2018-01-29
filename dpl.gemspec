$:.unshift File.expand_path("../lib", __FILE__)
require "dpl/version"

Gem::Specification.new do |s|
  s.name                  = "dpl"
  s.version               = DPL::VERSION
  s.author                = "Konstantin Haase"
  s.email                 = "konstantin.mailinglists@googlemail.com"
  s.homepage              = "https://github.com/travis-ci/dpl"
  s.summary               = %q{deploy tool}
  s.description           = %q{deploy tool abstraction for clients}
  s.license               = 'MIT'
  s.files                 = `git ls-files`.split("\n")
  s.test_files            = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables           = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_path          = 'lib'
  s.required_ruby_version = '>= 1.9.3'

  s.add_development_dependency 'rspec', '~> 3.7.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'rake'
  if RUBY_VERSION >= "2.4"
    s.add_development_dependency 'json', '~> 2'
  else
    s.add_development_dependency 'json', '1.8.3'
  end
  s.add_development_dependency 'tins', '~> 1.6.0', '>= 1.6.0'
  s.add_development_dependency 'coveralls'

  # prereleases from Travis CI
  if ENV['CI']
    digits = s.version.to_s.split '.'
    digits[-1] = digits[-1].to_s.succ
    s.version = digits.join('.') + ".travis.#{ENV['TRAVIS_JOB_NUMBER']}"
  end
end
