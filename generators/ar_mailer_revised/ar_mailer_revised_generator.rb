class ArMailerRevisedGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      model_name = (name || 'Email').classify

      #Create the model
      m.template 'model.rb', "app/models/#{model_name.downcase.underscore}.rb", :assigns => {:model_name => model_name}

      #Create the migration
      m.migration_template 'migration.rb', 'db/migrate', :migration_file_name => "create_#{model_name.downcase.underscore.pluralize}",
                                                         :assigns => {:model_name => model_name}

      #Create the initializer
      m.template 'initializer.rb', 'config/initializers/ar_mailer_revised.rb', :assigns => {:model_name => model_name}
    end
  end

  protected

  def banner
    "Usage: #{$0} ar_mailer_revised MODEL_NAME"
  end
end
