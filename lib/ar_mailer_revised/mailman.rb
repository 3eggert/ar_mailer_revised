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
      total_mail_count = ActionMailer::Base.email_class.ready_to_deliver.count
      emails           = ActionMailer::Base.email_class.ready_to_deliver.with_batch_size(@options[:batch_size])

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



    def deliver(emails)
      daemon_log = Logger.new 'daemon'
      daemon_log.level = Log4r::DEBUG
      filename = File.join(File.dirname(__FILE__)) + "/../../../log/XMailer.log"
      file_log = Log4r::FileOutputter.new('daemon', :filename => filename, :trunc => false)
      file_log.formatter = PatternFormatter.new(:pattern => "[%l] %d :: %m")
      daemon_log.outputters = file_log
      daemon_log.info "Custom ARMailer started. In vz.admin."

      settings = emails.collect{|x| x.settings }.uniq.compact
      settings << smtp_settings

      used_settings = [] #even though the settings are being uniqed, it was necessary...
      for setting in settings
        next if used_settings.include?(setting.to_s)
        used_settings << setting.to_s
        daemon_log.info "SETTING FOR %s" % [setting[:address]]
        user = setting[:user] || setting[:user_name]
        begin
          Net::SMTP.start setting[:address], setting[:port],
                          setting[:domain], user,
                          setting[:password],
                          setting[:authentication],
                          setting[:tls] do |smtp|
            @failed_auth_count = 0

            for email in emails
              email.settings = smtp_settings if email.settings.nil?
              next if email.settings.to_s != setting.to_s
              begin
                res = smtp.send_message email.mail, email.from, email.to
                email.destroy
                daemon_log.info "sent email %011d from %s to %s: %p via server: %s and domain: %s" %
                                    [email.id, email.from, email.to, res, setting[:address], setting[:domain]]
              rescue Net::SMTPFatalError => e
                daemon_log.info "5xx error sending email %d, removing from queue: %p(%s):\n\t%s" %
                                    [email.id, e.message, e.class, e.backtrace.join("\n\t")]
                email.destroy
                smtp.reset
              rescue Net::SMTPServerBusy => e
                daemon_log.info "server too busy, sleeping #{@delay} seconds"
                sleep delay
                return
              rescue Net::SMTPUnknownError, Net::SMTPSyntaxError, TimeoutError => e
                email.last_send_attempt = Time.now.to_i
                email.save rescue nil
                daemon_log.info "error sending email %d: %p(%s):\n\t%s" %
                                    [email.id, e.message, e.class, e.backtrace.join("\n\t")]
                smtp.reset
              end
            end
            daemon_log.info "Custom ARMailer finished."
          end #end SMTP
            #settings wrong? send email from standard server
        rescue Net::SMTPAuthenticationError => e
          daemon_log.info "Authentication Error. Settings wrong?"
          daemon_log.info "Complete Error: " + e.to_s
          daemon_log.info "Username and Password: " + (setting[:user] || setting[:user_name]) + " / " + setting[:password]
          for email in emails
            if email.settings.to_s == setting.to_s
              daemon_log.info "Updates settings to nil for %011d" % [email.id]
              email.settings = nil
              email.save
            end
          end
        rescue Exception => e
          daemon_log.info "smtp error: #{e.inspect}, #{e.message}"
          for email in emails
            if not email.settings.nil? and email.settings.to_s == setting.to_s
              daemon_log.info "Updated settings to nil for %011d" % [email.id]
              email.settings = nil
              email.save
            end
          end
        end
      end #for setting
    rescue Net::SMTPAuthenticationError => e
      @failed_auth_count += 1
      if @failed_auth_count >= MAX_AUTH_FAILURES then
        daemon_log.info "authentication error, giving up: #{e.message}"
        raise e
      else
        daemon_log.info "authentication error, retrying: #{e.message}"
      end
      sleep delay
    rescue Net::SMTPServerBusy, SystemCallError, OpenSSL::SSL::SSLError
      # ignore SMTPServerBusy/EPIPE/ECONNRESET from Net::SMTP.start's ensure
    end

  end
end