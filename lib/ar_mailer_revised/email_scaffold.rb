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
# @attr [Date] delivery_date
#   Field for the customized ARMailer. If this is set, the email won't be sent before the given date.
#   This is used for delayed emails, e.g. "post stay emails"
#
# @attr [Hash] smtp_settings
#   Serialized Hash storing custom SMTP settings just for this email.
#   If this value is +nil+, the system will use the default SMTP settings
#

module ArMailerRevised
  module EmailScaffold

    extend ActiveSupport::Concern

    included do
      serialize :smtp_settings

      #Only emails which are to be sent immediately
      scope :without_delayed,  lambda {where(:delivery_time => nil)}

      #All emails which are ready to be sent.
      #They are automatically sorted so that emails which already had a send attempt
      #will be last in the queue as they might fail again.
      scope :ready_to_deliver, lambda {where('delivery_time IS NULL OR delivery_time <= ?', Time.now).order('last_send_attempt ASC')}

      #Applies a +limit+ to the finder if batch_size is set
      scope :with_batch_size, lambda {|batch_size|
        batch_size ? {:limit => batch_size} : {}
      }
    end


    module ClassMethods

    end

  end
end