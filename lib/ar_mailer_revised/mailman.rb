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
      total_mail_count = ArMailerRevised.email_class.ready_to_deliver.count
      emails           = ArMailerRevised.email_class.ready_to_deliver.with_batch_size(@options[:batch_size])

      if emails.empty?
        logger.info 'No emails to be sent, existing'
        return
      end

      logger.info "Starting batch sending process, sending #{emails.count} / #{total_mail_count} mails"

      group_emails_by_settings(emails).each do |setting, grouped_emails|
        logger.info "Using setting #{setting.domain}/#{setting.user_name}"

        smtp = Net::SMTP.new setting.host, setting.port

        #Enable StartTLS if wished.
        #TODO: Make sure that it's really starttls what we need here
        smtp.enable_starttls if setting.use_tls

        #Connect to the server and handle possible errors
        begin
          smtp.start(setting.domain, setting.user_name, setting.password, setting.authentication) do
            grouped_emails.each do |email|
              logger.info "Sending Email ##{email.id}"

              #Try to send the email and handle possible errors
              begin
                smtp.send_message(email.mail, email.from, email.to)
                email.destroy
              rescue Net::SMTPServerBusy => e
                logger.warn 'Server is currently busy, trying again next batch'
                logger.warn 'Complete Error: ' + e.to_s
              rescue Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError, Net::ReadTimeout => e
                logger.warn 'Other Exception. Adjusting last_send_attempt and trying again next batch'
                logger.warn 'Complete Error: ' + e.to_s
                email.last_send_attempt = Time.now.to_i
                email.save(false)
              end
            end
          end
        rescue Net::SMTPAuthenticationError => e
          logger.warn 'SMTP authentication failed. Setting default SMTP settings for all affected emails. They will be sent next batch'
          logger.warn 'Complete Error: ' + e.to_s

          grouped_emails.each do |email|
            logger.info "Removed custom email settings for Email ##{email.id}"
            email.smtp_settings = nil
            email.save(false)
          end
        rescue Net::SMTPServerBusy => e
          logger.warn 'Server is busy, trying again next batch.'
          logger.warn 'Complete Error: ' + e.to_s
        rescue Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError, Net::OpenTimeout, Net::ReadTimeout => e
          #TODO: Should we remove the custom SMTP settings here as well?
          logger.warn 'Other SMTP error, trying again next batch.'
          logger.warn 'Complete Error: ' + e.to_s
        rescue Exception => e
          logger.warn 'Other Error, trying again next batch.'
          logger.warn 'Complete Error: ' + e.to_s
        end
      end

    end

    private

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
        if email.smtp_settings
          hash[smtp_settings] ||= []
          hash[smtp_settings] << email
        else
          hash[ActionMailer::Base.smtp_settings] ||= []
          hash[ActionMailer::Base.smtp_settings] << email
        end
        hash
      end
    end
  end
end