#
# Helper methods for the chosen email class
#

module ArMailerRevised
  module EmailScaffold

    def self.included(base)
      base.serialize :smtp_settings

      #Only emails which are to be sent immediately
      base.named_scope :without_delayed, lambda { {:conditions => {:delivery_time => nil} }}

      #All emails which are to be sent in the future
      base.named_scope :delayed, lambda { {:conditions => ['delivery_time > ?', Time.now]}}
    end

    #
    # @return [Boolean] +true+ if the system tried to send
    #   the email before.
    #
    def previously_attempted?
      last_send_attempt > 0
    end

    #
    # @return [Boolean] +true+ if this email is to be sent in the future
    #
    def delayed?
      !!(delivery_time && delivery_time > Time.now)
    end
  end
end