module ArMailerRevised
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('../templates', __FILE__)

      argument :model_name, :type => :string, :default => "Email"
      argument :model_backup_name, :type => :string, :default => "EmailBackup"
      argument :model_failed_name, :type => :string, :default => "FailedEmail"

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
        template 'model.rb', "app/models/#{model_name.classify.underscore}.rb"
        migration_template 'migration.rb', "db/migrate/create_#{model_name.classify.underscore.pluralize}.rb"
        if model_backup_name.present?
          template 'model_backup.rb', "app/models/#{model_backup_name.classify.underscore}.rb"
          migration_template 'migration.rb', "db/migrate/create_#{model_backup_name.classify.underscore.pluralize}.rb"
        end
        if model_failed_name.present?
          template 'model_failed.rb', "app/models/#{model_failed_name.classify.underscore}.rb"
          migration_template 'migration.rb', "db/migrate/create_#{model_failed_name.classify.underscore.pluralize}.rb"
        end

        initializer 'ar_mailer_revised.rb', <<INIT
ArMailerRevised.configuration do |config|

  #The model your application is using for email sending.
  #If you created it using the ArMailerRevised generator, the below
  #model name should already be correct.
  config.email_class = \"#{model_name}\"
  #{"config.email_backup_class = \"" + model_backup_name + "\"" if model_backup_name.present?}
  #{"config.email_failed_class = \"" + model_failed_name + "\"" if model_failed_name.present?}

end
INIT
      end
    end
  end
end
