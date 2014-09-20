#
# Adds sending email through an ActiveRecord table as a delivery method for
# ActionMailer.
#

class ActionMailer::Base
  #
  # Sets a custom email class attribute. It can be used
  # if the user wants to set custom attributes on his email records,
  # e.g. to track them later.
  # They are automatically set as attributes in the resulting AR record,
  # so make sure that they actually exist as database columns!
  #
  # @example Setting a client id to track which client sent the email
  #     ar_mailer_attribute :client_id, @client.id
  #
  def ar_mailer_attribute(key, value = nil)
    attrs = ar_mailer_setting(:custom_attributes) || {}
    if value
      attrs[key.to_s] = value
      ar_mailer_setting(:custom_attributes, attrs)
    else
      attrs[key.to_s]
    end
  end

  #
  # Sets custom SMTP settings just for this email
  #
  def ar_mailer_smtp_settings(new_settings = nil)
    ar_mailer_setting(:smtp_settings, new_settings)
  end

  #
  # Sets a delivery time for this email. If left at +nil+,
  # the email is sent immediately.
  #
  def ar_mailer_delivery_time(new_time = nil)
    ar_mailer_setting(:delivery_time, new_time)
  end

  private

  #
  # Sets or simply returns an ar_mailer_setting
  #
  def ar_mailer_setting(key, value = nil)
    if headers[:ar_mailer_settings]
      settings = YAML.load(headers[:ar_mailer_settings]).stringify_keys
    else
      settings = {}
    end

    if value
      settings[key.to_s] = value
      headers[:ar_mailer_settings] = YAML.dump(settings)
    else
      settings[key.to_s]
    end
  end

end

#
# This class contains the actual sending functionality
#
module ActionMailer
  class DeliveryMethodActiveRecord
    #
    # The delivery method seems to be called with a settings hash from the mail gem.
    #
    def initialize(settings)
      @settings = settings
    end

    #
    # Actually creates the email record in the database
    #
    def deliver!(mail)
      if mail['ar_mailer_settings']

        puts mail['ar_mailer_settings'].value

        ar_settings = YAML.load(mail['ar_mailer_settings'].value)
        ar_settings = ar_settings.stringify_keys
        mail['ar_mailer_settings'] = nil
      else
        ar_settings = {}
      end

      email_options = {}
      email_options[:delivery_time] = ar_settings.delete('delivery_time')
      email_options[:smtp_settings] = ar_settings.delete('smtp_settings')
      email_options[:mail]          = mail.encoded
      email_options[:from]          = (mail['return-path'] && mail['return-path'].spec) || mail.from.first
      email_options.reverse_merge!(ar_settings['custom_attributes'] || {})

      mail.destinations.each do |destination|
        ArMailerRevised.email_class.create!(email_options.merge({:to => destination}))
      end
    end
  end
end


