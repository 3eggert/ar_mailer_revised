require_relative '../test_helper'

class InstallGeneratorTest < Rails::Generators::TestCase
  tests ArMailerRevised::Generators::InstallGenerator
  destination File.expand_path('../dummy/tmp', File.dirname(__FILE__))
  setup    :prepare_destination

  test 'Assert all files are properly created' do
    run_generator
    assert_file 'config/initializers/ar_mailer_revised.rb'
    assert_file 'app/models/email.rb'
    assert_migration 'db/migrate/create_emails.rb'
  end
end