# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ar_mailer_revised/version'

Gem::Specification.new do |spec|
  spec.name          = 'ar_mailer_revised'
  spec.version       = ArMailerRevised::VERSION
  spec.authors       = ['Stefan Exner']
  spec.email         = ['stex@sterex.de']
  spec.description   = %q{Even delivering email to the local machine may take too long when you have to send hundreds of messagespec.  ar_mailer allows you to store messages into the database for later delivery by a separate process, ar_sendmail.}
  spec.summary       = 'Batch email sending for rails applications'
  spec.homepage      = 'http://www.github.com/stex/ar_mailer_revised'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'redcarpet', '~> 2.3.0'

  spec.add_dependency 'actionmailer', '~> 4'
  spec.add_dependency 'log4r'
end
