module ArMailerRevised
  module Helpers
    module CommandLine

      class RailsEnvironmentFailed < StandardError; end

      ##
      # Processes +args+ and runs as appropriate

      def self.run(args = ARGV)
        options = process_args(args)

        if options[:display_queue]
          display_mail_queue
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
      #
      # If ActiveRecord::Timestamp is not being used the arrival time will not be
      # known. See http://api.rubyonrails.org/classes/ActiveRecord/Timestamp.html
      # to learn how to enable ActiveRecord::Timestamp.

      def self.display_mail_queue
        emails = ActionMailer::Base.email_class.find :all

        if emails.empty? then
          puts "Mail queue is empty"
          return
        end

        total_size = 0

        puts "-Queue ID- --Size-- ----Arrival Time---- -Sender/Recipient-------"
        emails.each do |email|
          size = email.mail.length
          total_size += size

          create_timestamp = email.created_on rescue
              email.created_at rescue
                  Time.at(email.created_date) rescue # for Robot Co-op
                      nil

          created = if create_timestamp.nil? then
                      ' Unknown'
                    else
                      create_timestamp.strftime '%a %b %d %H:%M:%S'
                    end

          puts "%10d %8d %s %s" % [email.id, size, created, email.from]
          if email.last_send_attempt > 0 then
            puts "Last send attempt: #{Time.at email.last_send_attempt}"
          end
          puts " #{email.to}"
          puts
        end

        puts "-- #{total_size/1024} Kbytes in #{emails.length} Requests."
      end

      def self.process_args(args)
        name = File.basename $0

        options = {}
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

          opts.on( "--max-age MAX_AGE",
                   "Maxmimum age for an email. After this",
                   "it will be removed from the queue.",
                   "Set to 0 to disable queue cleanup.",
                   "Default: #{options[:max_age]} seconds", Integer) do |max_age|
            options[:max_age] = max_age
          end

          opts.on( '--mailq',
                   'Display a list of emails waiting to be sent') do |mailq|
            options[:display_queue] = true
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
                  "Default: #{options[:RailsEnv]}") do |env|
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
          load_rails_environment(options[:ch_dir])
        rescue RailsEnvironmentFailed
          usage opts, <<-EOF
#{name} must be run from a Rails application's root to deliver email.
#{Dir.pwd} does not appear to be a Rails application root.
          EOF
        end

        return options
      end

      #
      # Loads the complete rails environment
      #
      def self.load_rails_environment(base_path)
        Dir.chdir(base_path) do
          require 'config/environment'
          require 'action_mailer/ar_mailer'
        end
      rescue LoadError
        raise RailsEnvironmentFailed
      end

      def self.usage(opts, message = nil)
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