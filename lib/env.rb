# encoding: utf-8

# TODO: Move files in lib/ into separate gems and remove the following lines.
$LOAD_PATH.unshift(File.expand_path('..', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../../../logging/lib', __FILE__))

require 'amq/client'
require 'eventmachine'

require 'pluginable'

class Stream
  extend Pluginable

  # Configuration.
  plugin(:configuration) do
    require 'configurable'

    extend Configurable::Mixin

    def config
      @config ||= self.class.config
    end

    require_relative '../config/amqp'
  end

  # Logging.
  plugin(:logging) do
    require 'logging'
    require 'logging/code'

    def logger
      @logger ||= Logging::Logger.new do |logger|
        logger.io = Logging::IO::Pipe.new('stream.logs.app', '/tmp/loggingd.pipe')
        logger.formatter = Logging::Formatters::Colourful.new
      end
    end
  end

  def initialize(&block)
    block.call(self) if block
  end

  # Implementation.
  def amqp(&block)
    logger.info("Connecting to AMQP.")
    logger.inspect(self.config.amqp.to_h)

    AMQ::Client.connect(self.config.amqp.to_h) do |connection|
      self.setup_signal_handlers(connection)

      channel = AMQ::Client::Channel.new(connection, 1)
      channel.open

      exchange = AMQ::Client::Exchange.new(connection, channel, "amq.fanout", :fanout)

      logger.info("AMQP connection established.")
      block.call(connection, channel, exchange)
    end
  end

  def subscribe(name = 'stream.ideas', auto_delete = false, &block)
    amqp do |connection, channel, exchange|
      queue = AMQ::Client::Queue.new(connection, channel, name)

      queue.declare(false, false, false, auto_delete) do
        logger.info("Server-named queue #{queue.name.inspect} is ready")
      end

      queue.bind(exchange.name) do
        logger.info("Queue #{queue.name} is now bound to #{exchange.name}")
      end

      queue.consume(true) do |consume_ok|
        logger.info("Subscribed for messages routed to #{queue.name}, consumer tag is #{consume_ok.consumer_tag}, using no-ack mode")

        queue.on_delivery do |basic_deliver, header, payload|
          block.call(payload, header, basic_deliver)
        end
      end
    end
  end

  # Signal handling.
  def setup_signal_handlers(connection)
    ['INT', 'TERM'].each do |signal|
      Signal.trap(signal) do
        puts "~ Received #{signal} signal, terminating."
        connection.disconnect { EM.stop }
      end
    end
  end
end
