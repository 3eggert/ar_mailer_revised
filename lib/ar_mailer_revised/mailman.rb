#
# This class handles the actual email sending.
# It is called by the +ar_sendmail+ executable in /bin
# with command line arguments
#
# @author Stefan Exner
#

require 'net/smtp'
require 'ar_mailer_revised/version'
require 'ar_mailer_revised/helpers/command_line'
require 'ar_mailer_revised/helpers/general'

module ArMailerRevised
  class Mailman
    include ArMailerRevised::Helpers::General
    include ArMailerRevised::Helpers::CommandLine

    #
    # Simply holds a copy of the options given in from command line
    #
    def initialize(options = {})
      @options = options
    end

    def run
     logger.info "ArMailerRevised--> enter Mailman:run"
     logger.info "ArMailerRevised initialized with the following options:\n" + Hirb::Helpers::AutoTable.render(@options)
     deliver_emails
    end

    private

    #
    # Performs a single email sending for the given batch size
    # Only emails which are ready for sending are actually sent.
    # "Ready for sending" means in this case, that +delivery_time+ is +nil+
    # or set to a time which is <= Time.now
    #
    # Take a look at +EmailScaffold+ for more information
    # about the used scopes
    #
    # @todo: Check if we should delete emails which cause SMTPFatalErrors
    # @todo: Probably add better error handling than simple re-tries
    #
    def deliver_emails
      logger.info "ArMailerRevised--> enter Mailman:deliver_email:"
      total_mail_count = ArMailerRevised.email_class.ready_to_deliver.count
      emails           = ArMailerRevised.email_class.ready_to_deliver.with_batch_size(@options[:batch_size])

      if emails.empty?
        logger.info 'No emails to be sent, existing'
        return
      end

      logger.info "Starting batch sending process, sending #{emails.count} / #{total_mail_count} mails"

      group_emails_by_settings(emails).each do |settings_hash, grouped_emails|
        setting = OpenStruct.new(settings_hash)
        logger.info "Using setting #{setting.address}:#{setting.port}/#{setting.user_name}"

        smtp = Net::SMTP.new(setting.address, setting.port)
        smtp.open_timeout = 60
        smtp.read_timeout = 60
        setup_tls(smtp, setting)

        #Connect to the server and handle possible errors
        begin
          smtp.start(setting.domain, setting.user_name, setting.password, setting.authentication) do
            grouped_emails.each do |email|
              send_email(smtp, email)
            end
          end
        rescue Net::SMTPAuthenticationError => e
          handle_smtp_authentication_error(setting, e, grouped_emails)
        rescue Net::SMTPSyntaxError => e
          handle_smtp_syntax_error(setting, e, grouped_emails)
        rescue Net::SMTPServerBusy => e
          logger.warn 'Net::SMTPServerBusy: Server is busy, trying again next batch.'
          logger.warn 'Complete Error: ' + e.to_s
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          handle_smtp_timeout(setting, e, grouped_emails)
        rescue Net::SMTPFatalError, Net::SMTPUnknownError => e
          #TODO: Should we remove the custom SMTP settings here as well?
          logger.warn 'Net::SMTPFatalError: Other SMTP error, trying again next batch.'
          logger.warn 'Complete Error: ' + e.to_s
        rescue OpenSSL::SSL::SSLError => e
          handle_ssl_error(setting, e, grouped_emails)
        rescue Exception => e
          handle_other_exception(setting, e, grouped_emails)
        end
      end
    end

    #
    # As there may be multiple emails using the same SMTP settings,
    # it would just slow down the sending having to connect to the server
    # multiple times. Therefore, all emails with the same settings
    # are grouped together.
    #
    # @param [Array<Email>] emails
    #   Emails to be grouped together
    #
    # @return [Hash<Setting, Email>]
    #   Hash mapping SMTP settings to emails.
    #   All emails which did not have custom SMTP settings are
    #   grouped together under the default SMTP settings.
    #
    def group_emails_by_settings(emails)
      emails.inject({}) do |hash, email|
        setting = ActionMailer::Base.smtp_settings

        if email.smtp_settings
          setting = email.smtp_settings.clone
          setting[:custom_setting] = true
        end

        hash[setting] ||= []
        hash[setting] << email

        hash
      end
    end

    #
    # Sets the wished TLS / StartTLS options in the
    # given SMTP instance, based on what the user defined
    # in his application's / the email's SMTP settings.
    #
    # Available Settings are (descending importance, meaning that
    # a higher importance setting will override a lower importance setting)
    #
    # 1. +:enable_starttls_auto+ enables STARTTLS if the serves is capable to handle it
    # 2. +:enable_starttls+ forces the usage of STARTTLS, whether the server is capable of it or not
    # 3. +:tls+ forces the usage of TLS (SSL SMTP)
    #
    def setup_tls(smtp, setting)
      if setting.enable_starttls_auto
        logger.debug 'Using STARTTLS, if the server accepts it'
        smtp.enable_starttls_auto(build_ssl_context(setting))
      elsif setting.enable_starttls
        logger.debug 'Forcing STARTTLS'
        smtp.enable_starttls(build_ssl_context(setting))
      elsif setting.tls
        logger.debug 'Forcing TLS'
        smtp.enable_tls(build_ssl_context(setting))
      else
        logger.debug 'Disabling TLS'
        smtp.disable_tls
      end
    end

    #
    # @return [Boolean] +true+ if TLS is used in any kind (STARTLS auto, STARTLS or TLS)
    #
    def use_tls?(setting)
      setting.enable_starttls_auto || setting.enable_starttls || setting.enable_tls
    end

    #
    # Builds an SSL context to be used if TLS is enabled for the given setting
    # At the moment it only sets the chosen verify_mode, but it might be extended later.
    #
    def build_ssl_context(setting)
      c = OpenSSL::SSL::SSLContext.new
      if use_tls?(setting)
        logger.debug "Using SSL verify mode: #{setting.openssl_verify_mode}"
        c.verify_mode = setting.openssl_verify_mode
      end
      c
    end

    #
    # Performs an email sending attempt
    #
    # @param [Net::SMTP] smtp
    #   The SMTP connection which already has to be established
    #
    # @param [Email]
    #   The email record to be sent.
    #
    # Error handling works as follows:
    #
    #   - If the server is busy while sending the email (SMTPServerBusy),
    #     the system will leave the email at its old place in the queue and try
    #     again next batch as we simply assume that the server failure is just temporarily
    #     and the email will not cause the whole email sending to stagnate
    #
    #   - If another error occurs, the system will adjust the last_send_attempt
    #     in the email record and therefore move it to the end of the queue to
    #     ensure that other (working) emails are sent without being held up
    #     in the queue by this probably malformed one.
    #
    # Errors are logged with the :warn level.
    #
    def send_email(smtp, email)
      logger.info "ArMailerRevised--> enter Mailman:send_email"
      email.fail_reasons = {} if email.fail_reasons.nil?
      if email.failed_tries.to_i > 6
        logger.info "retry count exeeded Email ##{email.id}"
        email_hash = email.attributes
        email_hash.delete("id")
        ArMailerRevised.email_failed_class.create(email_hash)
        email.destroy
        return
      end
      logger.info "Sending Email 1 ##{email.id}"
      smtp.send_message(email.mail, email.from, email.to)
      email_hash = email.attributes
      email_hash.delete("id")
      ArMailerRevised.email_backup_class.create(email_hash)
      email.destroy
    rescue Net::SMTPServerBusy => e
      logger.warn 'Server is currently busy, trying again next batch'
      logger.warn 'Net::SMTPServerBusy: Complete Error: ' + e.to_s
    rescue Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError, Net::ReadTimeout => e
      logger.warn 'Net::SMTPSyntaxError: Other exception, trying again next batch: ' + e.to_s
      email.failed_tries = email.failed_tries.to_i + 1
      email.fail_reasons.merge!(email.failed_tries=>e.to_s)
      email.save
      adjust_last_send_attempt!(email)
    rescue Exception => e
      raise e
    end

    #-----------------------------------------------------------------
    #                    SMTP connection error handling
    # These errors happen directly when connecting to the SMTP server
    #-----------------------------------------------------------------

    #
    # Handles Net::OpenTimeout and Net::ReadTimeout occurring
    # while connecting to an SMTP server.
    #
    # If the setting was a custom SMTP setting, it will be removed from
    # all given emails - but only if it failed before.
    # With this, each email setting gets 2 tries.
    #
    # @param [OpenStruct] setting
    #   The used SMTP settings
    #
    # @param [Exception] exception
    #   The exception thrown
    #
    # @param [Array<Email>] emails
    #   All emails to be delivered using this system (in the current batch)
    #
    def handle_smtp_timeout(setting, exception, emails)
      logger.warn "SMTP connection timeout while connecting to '#{setting.address}:#{setting.port}'"
      logger.warn 'Complete Error: ' + exception.to_s

      if setting.custom_setting
        logger.warn 'Setting default SMTP settings for all affected emails, they will be sent next batch.'
        emails.each do |email|
          if email.previously_attempted?
            remove_custom_smtp_settings!(email)
          else
            adjust_last_send_attempt!(email)
          end
        end
      end
    end

    #
    # Handles SSL errors (mostly invalid certificates)
    # @see #handle_smtp_timeout
    #
    # Custom SMTP settings will be deleted and the default server will be used.
    #
    def handle_ssl_error(setting, exception, emails)
      logger.warn "SSL error while connecting to '#{setting.address}:#{setting.port}'"
      logger.warn 'Complete Error: ' + exception.to_s
      handle_custom_setting_removal(setting, emails)
    end

    #
    # Handles authentication errors occuring while connecting to an SMTP server.
    # @see #handle_smtp_timeout
    #
    # The main difference is, that custom SMTP settings will be deleted directly
    # as it isn't very likely that time will solve the error.
    #
    def handle_smtp_authentication_error(setting, exception, emails)
      logger.warn "SMTP authentication error while connecting to '#{setting.address}:#{setting.port}'"
      logger.warn 'Complete Error: ' + exception.to_s
      handle_custom_setting_removal(setting, emails)
    end

    #
    # Handles SMTP syntax errors.
    # @see #handle_smtp_timeout
    #
    def handle_smtp_syntax_error(setting, exception, emails)
      logger.warn "SMTP syntax error while connecting to '#{setting.host}:#{setting.port}'"
      logger.warn 'Complete Error: ' + exception.to_s
      handle_custom_setting_removal(setting, emails)
    end

    #
    # Handles other errors occuring while sending the email
    # Custom settings are removed here as well as the gem itself
    # most likely has to be altered to send these emails out using
    # the custom settings - which might take a while.
    #
    def handle_other_exception(setting, exception, emails)
      logger.warn "Other error while connecting to '#{setting.host}:#{setting.port}'"
      logger.warn "Complete Error (#{exception.class.to_s}): " + exception.to_s
      handle_custom_setting_removal(setting, emails)
    end

    #----------------------------------------------------------------
    #                    Email Record Alteration
    #----------------------------------------------------------------

    #
    # Removes custom settings for all given emails
    #
    def handle_custom_setting_removal(setting, emails)
      if setting.custom_setting
        logger.warn 'Setting default SMTP settings for all affected emails, they will be sent next batch.'
        emails.each { |email| remove_custom_smtp_settings!(email) }
      else
        emails.each { |email| adjust_last_send_attempt!(email) }
        logger.error "Your application's base setting ('#{setting.host}:#{setting.port}') produced an error!"
      end
    end

    #
    # Adjusts the last send attempt timestamp in the given
    # email to the current time.
    #
    def adjust_last_send_attempt!(email)
      logger.info "Setting last send attempt for email ##{email.id} (was: #{email.last_send_attempt})"
      email.last_send_attempt = (Time.now + (email.failed_tries.to_i**4).minutes).to_i
      email.save(:validate => false)
    end

    #
    # Removes the custom smtp settings from a given email record
    # and saves it without validations
    #
    def remove_custom_smtp_settings!(email)
      logger.info "Removing custom SMTP settings (#{email.smtp_settings[:address]}:#{email.smtp_settings[:port]}) for email ##{email.id}"
      email.smtp_settings = nil
      email.save(:validate => false)
    end
  end
end
