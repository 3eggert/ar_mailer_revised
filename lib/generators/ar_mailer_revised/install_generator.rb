module ArMailerRevised
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('../templates', __FILE__)

      def self.next_migration_number(path)
        if @prev_migration_nr
          @prev_migration_nr += 1
        else
          @prev_migration_nr = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        end
        @prev_migration_nr.to_s
      end

      desc 'Installs everything necessary'
      def create_install
        'ArMailerRevised installation'
        if yes?('Generate email model and migration? [yes/no]')
          @model_name = ask 'Please enter a name for the message model: [Email]'
          template 'model.rb', "app/models/#{model_name.underscore}.rb"
          migration_template 'migration.rb', "db/migrate/create_#{model_name.underscore.pluralize}.rb"
        end

        initializer 'ar_mailer_revised.rb', <<INIT
ArMailerRevised.configuration do |config|
  config.email_class = #{model_name}
end
INIT
      end

      private

      def model_name
        @model_name.blank? ? 'Email' : @model_name.classify
      end

      desc 'Creates a migration for the email table'
      def create_migration
        migration_template 'create_emails.rb', 'db/migrate/create_emails.rb'
        initializer
      end
    end
  end
end
