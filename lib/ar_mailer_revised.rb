require 'ar_mailer_revised/version'
require 'action_mailer/ar_mailer'
require 'ar_mailer_revised/email_scaffold'

#Register the new delivery method
ActionMailer::Base.add_delivery_method :activerecord, ActionMailer::DeliveryMethodActiveRecord