#
# This class handles the actual email sending.
# It is called by the +ar_sendmail+ executable in /bin
# with command line arguments
#
# @author Stefan Exner
#

require 'optparse'
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

  end
end