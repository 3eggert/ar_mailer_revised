# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'ar_mailer_revised/version'

Gem::Specification.new do |spec|
  spec.name          = 'ar_mailer_revised'
  spec.version       = ArMailerRevised::VERSION
  spec.authors       = ['Stefan Exner']
  spec.email         = ['stex@sterex.de']
  spec.description   = %q{Allows Batch-Sending emails in Ruby on Rails applications including delayed emails and custom SMTP settings per email}
  spec.summary       = 'Batch email sending for rails applications'
  spec.homepage      = 'http://www.github.com/stex/ar_mailer_revised'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'yard', '~> 0.8'
  spec.add_development_dependency 'redcarpet', '~> 2.3'
  spec.add_development_dependency 'sqlite3', '~> 1'
  spec.add_development_dependency 'minitest', '~> 5.3'
  spec.add_development_dependency 'shoulda', '~> 3.5'
  spec.add_development_dependency 'mailcatcher', '~> 0.2'

  spec.add_dependency 'rails', '~> 5.1'
  spec.add_dependency 'log4r', '~> 1'
  spec.add_dependency 'hirb', '~> 0'

  spec.required_ruby_version = '~> 2.4'
end
