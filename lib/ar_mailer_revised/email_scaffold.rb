# Email Class Extensions for use with ARMailer
#
# @attr [String] from
#   The email sender
#
# @attr [String] to
#   The email recipient
#
# @attr [Integer] last_send_attempt
#   Unix timestamp containing the last time the system tried to deliver this email.
#   The value will be +nil+ if there wasn't a send attempt yet
#
# @attr [String] mail
#   The mail body, including the mail header information (from, to, encoding, ...)
#
# @attr [Date] date_to_send
#   Field for the customized ARMailer. If this is set, the email won't be sent before the given date.
#   This is used for delayed emails, e.g. "post stay emails"
#
# @attr [String] record_identifier
#   Field used to connect an email / sent email to a certain record in vz.rooms that caused its sending.
#   The record identifier is a string containing e.g. the client id and record class / id
#
# @attr [Hash] settings
#   Serialized Hash storing custom SMTP settings just for this email.
#   If this value is +nil+, the system will use the default SMTP settings
#

module ArMailerRevised
  module EmailScaffold

    def self.included(base)
      base.class_eval do
        base.send :extend, ClassMethods
      end
    end

    module ClassMethods
      serialize :settings

      #Only emails which are to be send immediately
      scope :without_delayed,  -> {where(:date_to_send => nil)}

      #All emails which are ready to be sent
      scope :ready_to_deliver, -> {where('emails.date_to_send IS NULL OR emails.date_to_send <= ?', Time.now.to_date)}
    end

  end
end