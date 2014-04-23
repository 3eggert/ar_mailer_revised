#
# Helper methods for the chosen email class
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