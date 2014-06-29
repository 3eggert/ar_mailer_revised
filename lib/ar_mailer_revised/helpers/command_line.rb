require 'hirb'
require 'optparse'

module ArMailerRevised
  module Helpers
    module CommandLine

      class RailsEnvironmentFailed < StandardError;
      end

      def self.included(base)
        base.class_eval do
          base.send :extend, ClassMethods
        end
      end

      module ClassMethods

        ##
        # Processes +args+ and runs as appropriate

        def run(args = ARGV)
          options = process_args(args)

          if options[:display_queue]
            display_mail_queue(options[:display_queue])
            exit
          end

          new(options).run

        rescue SystemExit
          raise
        rescue SignalException
          exit
        rescue Exception => e
          $stderr.puts "Unhandled exception #{e.message}(#{e.class}):"
          $stderr.puts "\t#{e.backtrace.join "\n\t"}"
          exit -2
        end

        ##
        # Prints a list of unsent emails and the last delivery attempt, if any.
        # Only emails which are ready to deliver are displayed
        #
        def display_mail_queue(what)
          emails = case what
                     when 'all' then
                       puts 'Showing all emails in the system'
                       ArMailerRevised.email_class.all
                     when 'deliverable' then
                       puts 'Showing emails ready to deliver'
                       ArMailerRevised.email_class.ready_to_deliver
                     when 'delayed' then
                       puts 'Showing delayed emails'
                       ArMailerRevised.email_class.delayed
                     else
                       []
                   end
        puts 'Mail queue is empty' and return if emails.empty?
        puts Hirb::Helpers::AutoTable.render emails, :fields => [:from, :to, :delivery_time, :last_send_attempt, :updated_at]
      end

      def process_args(args)
        name = File.basename $0

        options             = {}
        options[:chdir]     = '.'
        options[:max_age]   = 86400 * 7
        options[:rails_env] = ENV['RAILS_ENV']
        options[:log_level] = 'info'
        options[:verbose]   = false

        opts = OptionParser.new do |opts|
          opts.banner = "Usage: #{name} [options]"
          opts.separator ''

          opts.separator "#{name} scans the email table for new messages and sends them to the"
          opts.separator "website's configured SMTP host."
          opts.separator ''
          opts.separator "#{name} must be run from a Rails application's root."

          opts.separator ''
          opts.separator 'Sendmail options:'

          opts.on("-b", "--batch-size BATCH_SIZE",
                  "Maximum number of emails to send per delay",
                  "Default: Deliver all available emails", Integer) do |batch_size|
            options[:batch_size] = batch_size
          end

          opts.on("--max-age MAX_AGE",
                  "Maxmimum age for an email. After this",
                  "it will be removed from the queue.",
                  "Set to 0 to disable queue cleanup.",
                  "Default: #{options[:max_age]} seconds", Integer) do |max_age|
            options[:max_age] = max_age
          end

          opts.on('--mailq [all|deliverable|delayed]',
                  'Display a list of emails waiting to be sent',
                  'Default: all') do |mailq|
            options[:display_queue] = mailq || 'all'
          end

          opts.separator ''
          opts.separator 'Generic Options:'

          opts.on('-l', '--log-file PATH',
                  'Custom log file location at PATH. May also be "stdout" or "stderr" for console output',
                  'Default: log/environment.log') do |path|
            dir = File.dirname(path)
            usage opts, "#{dir} is not an existing directory" unless File.exists?(dir) && File.directory?(dir)
            usage opts, "#{path} is a directory" if File.directory?(path)
            options[:log_file] = path
          end

          opts.on('--log-level LEVEL',
                  "Set the mailer's log LEVEL",
                  "Default: #{options[:log_level]}") do |level|
            usage opts, "Invalid log-level: #{level}" unless %w[debug info warn error fatal].include?(level.to_s.downcase)
            options[:log_level] = level
          end

          opts.on("-c", "--chdir PATH",
                  "Use PATH for the application path",
                  "Default: #{options[:chdir]}") do |path|
            usage opts, "#{path} is not a directory" unless File.directory? path
            usage opts, "#{path} is not readable" unless File.readable? path
            options[:chdir] = path
          end

          opts.on("-e", "--environment RAILS_ENV",
                  "Set the RAILS_ENV constant",
                  "Default: #{options[:rails_env]}") do |env|
            options[:rails_env] = env
          end

          opts.on("-v", "--[no-]verbose",
                  "Be verbose",
                  "Default: #{options[:verbose]}") do |verbose|
            options[:verbose] = verbose
          end

          opts.on("-h", "--help",
                  "You're looking at it") do
            usage opts
          end

          opts.on("--version", "Version of ARMailer") do
            usage "ar_mailer_revised #{VERSION}"
          end

          opts.separator ''
        end

        opts.parse! args

        ENV['RAILS_ENV'] = options[:rails_env]

        begin
          load_rails_environment(options[:chdir])
        rescue RailsEnvironmentFailed
          usage opts, <<-EOF
#{name} must be run from a Rails application's root to deliver email.
#{Dir.pwd} does not appear to be a Rails application root.
          EOF
        end

        options
      end

      #
      # Loads the complete rails environment
      #
      def load_rails_environment(base_path)
        Dir.chdir(base_path) do
          require File.join(base_path, 'config/environment')
          require 'action_mailer/ar_mailer'
        end
      rescue LoadError => e
        puts e
        raise RailsEnvironmentFailed
      end

      def usage(opts, message = nil)
        if message then
          $stderr.puts message
          $stderr.puts
        end

        $stderr.puts opts
        exit 1
      end
    end
  end
end
end