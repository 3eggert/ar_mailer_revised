#
# This module contains helper functionality for the Mailman class
# that handles the actual email sending as a batch process.
#
# @author Stefan Exner <stex@sterex.de>
#

require 'log4r'

module ArMailerRevised
  module Helpers
    module General
      #
      # Generates a logger object using Log4r
      # The output file is determined by +#log_file+
      #
      # If the custom log file path is set to +stdout+ or +stderr+,
      # these are used instead of a log file.
      #
      # @return [Log4r::Logger] the file output logger
      #
      def logger
        unless @logger
          @logger            = Log4r::Logger.new 'ar_mailer'

          if %w[stdout stderr].include?(@options[:log_file])
            outputter = Log4r::Outputter.send(@options[:log_file])
          else
            outputter = Log4r::FileOutputter.new('ar_mailer_log', :filename => log_file)
          end

          outputter.formatter = Log4r::PatternFormatter.new(:pattern => '[%5l - %c] %d :: %m')
          @logger.outputters = outputter

          @logger.level      = log_level
        end
        @logger
      end

      #
      # Determines the correct log file location
      # It defaults to the current environment's log file
      # @todo Check if that interferes with Rails' logging process
      #
      # @return [String] Path to the logfile
      #
      def log_file
        @log_file ||= @options[:log_file] ? File.expand_path(@options[:log_file]) : File.join(Rails.root, 'log', "#{rails_environment}.log")
      end

      #
      # Determines the correct log level from the given script arguments
      # Defaults to +INFO+
      #
      # @return [Int] a log level from +Log4r+
      #
      def log_level
        @log_level ||= "Log4r::#{@options[:log_level].upcase}".constantize
      end

      #
      # @return [String] the currently active rails environment
      #
      def rails_environment
        ENV['RAILS_ENV']
      end

      #
      # Checks if the given environment is currently active
      # Works like Rails.env.env?
      #
      # @param [String, Symbol] env
      #   The environment name
      #
      # @return [Bool] +true+ if the current environment matches the given
      def rails_environment?(env)
        rails_environment.to_s == env.to_s
      end
    end
  end
end