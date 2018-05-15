require 'ar_mailer_revised/version'
require 'action_mailer/ar_mailer'
require 'ar_mailer_revised/email_scaffold'

#Register the new delivery method
ActionMailer::Base.add_delivery_method :activerecord, ActionMailer::DeliveryMethodActiveRecord

module ArMailerRevised
  @@config ||= OpenStruct.new({
    :email_class => 'Email',
    :email_backup_class => 'EmailBackup',
    :email_failed_class => 'FailedEmail'
  })

  def self.configuration(&proc)
    @@config ||= OpenStruct.new({
      :email_class => 'Email',
      :email_backup_class => 'EmailBackup',
      :email_failed_class => 'FailedEmail'
    })
    if block_given?
      yield @@config
      @@config.email_class = (@@config.email_class || 'Email').to_s.classify
    else
      @@config
    end
  end

  #
  # @return [ActiveRecord::Base] (Email)
  #   The class used to create new emails in the system
  #
  def self.email_class
    self.email_class_name.constantize
  end

  #
  # @return [String] (Email)
  #   The email class' name
  #
  def self.email_class_name
    @@config.email_class.classify
  end

  #
  # @return [ActiveRecord::Base] (Email)
  #   The class used to create new emails in the system
  #
  def self.email_failed_class
    self.email_failed_class_name.constantize
  end

  #
  # @return [String] (Email)
  #   The email class' name
  #
  def self.email_failed_class
    @@config.email_failed_class.classify
  end

  #
  # @return [ActiveRecord::Base] (Email)
  #   The class used to create new emails in the system
  #
  def self.email_backup_class
    self.email_backup__class_name.constantize
  end

  #
  # @return [String] (Email)
  #   The email class' name
  #
  def self.email_backup_class
    @@config.email_backup__class.classify
  end
end
