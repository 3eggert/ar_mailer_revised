#
# Adds sending email through an ActiveRecord table as a delivery method for
# ActionMailer.
#

class ActionMailer::Base
  #
  # Sets the class which is used to create emails in
  # the system. Defaults to +Email+
  #
  # @param [ActiveRecord::Base, String, Symbol] klass
  #   Class to be used for email creation
  #
  def self.email_class=(klass)
    @@email_class_name = klass.to_s
  end

  #
  # @return [ActiveRecord::Base] (Email)
  #   The class used to create new emails in the system
  #
  def self.email_class
    self.email_class_name.constantize
  end

  #
  # @return [String]
  #   The email class' name
  #
  def self.email_class_name
    @@email_class_name ||= 'Email'
    @@email_class_name.classify
  end

  ##
  # Adds +mail+ to the Email table.  Only the first From address for +mail+ is
  # used.

  def perform_delivery_activerecord(mail)
    destinations = mail.destinations
    sender       = (mail['return-path'] && mail['return-path'].spec) || mail.from.first
    destinations.each do |destination|
      self.class.email_class.create :mail => mail.encoded, :to => destination, :from => sender
    end
  end

end
