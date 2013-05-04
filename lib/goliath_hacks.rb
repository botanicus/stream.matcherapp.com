# encoding: utf-8

Goliath::Runner.class_eval do
  def run
    if options[:console]
      Goliath::Console.run!(setup_server)
      return
    end

    unless Goliath.env?(:test)
      $LOADED_FEATURES.unshift(File.basename($0))
      Dir.chdir(File.expand_path(File.dirname($0)))
    end

    if @daemonize
      Process.fork do
        Process.setsid
        exit if fork

        @pid_file ||= './goliath.pid'
        @log_file ||= File.expand_path('goliath.log')
        store_pid(Process.pid)

        File.umask(0000)

        # stdout_log_file = "#{File.dirname(@log_file)}/#{File.basename(@log_file)}_stdout.log"

        STDIN.reopen("/dev/null")
        # STDOUT.reopen(stdout_log_file, "a")
        # STDERR.reopen(STDOUT)

        run_server
        remove_pid
      end
    else
      run_server
    end
  end

  def setup_logger
    Logging::Logger.new do |logger|
      logger.io = Logging::IO::Pipe.new('stream.logs.goliath', '/tmp/loggingd.pipe')
      logger.formatter = Logging::Formatters::Colourful.new
    end
  end
end
