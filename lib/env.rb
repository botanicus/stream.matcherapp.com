# encoding: utf-8

# TODO: Move files in lib/ into separate gems and remove the following lines.
$LOAD_PATH.unshift(File.expand_path('..', __FILE__))

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
        logger.io = Logging::IO::Raw.new('stream.logs.app')
        logger.formatter = Logging::Formatters::Colourful.new
      end
    end
  end

  def initialize(&block)
    block.call(self) if block
  end

  # Implementation.
  def amqp(&block)
    @connection ||= begin
      logger.info("Connecting to AMQP.")
      logger.inspect(self.config.amqp.to_h)

      connection = AMQ::Client.connect(self.config.amqp.to_h)
      connection.on_open do
        logger.info("AMQP connection established.")

        self.setup_signal_handlers(connection)
      end

      connection
    end

    @connection.on_open do
      channel = AMQ::Client::Channel.new(@connection, rand(1000))
      channel.open

      block.call(@connection, channel)
    end
  end

  def subscribe(exchange, &block)
    amqp do |connection, channel|
      log_exchange = AMQ::Client::Exchange.new(@connection, channel, 'amq.topic', :topic)

      logger.info("Writing logs into #{log_exchange.name} exchange now.")
      logger.info("Run ./bin/inspect.rb to inspect them.")
      logger.io = Logging::IO::AMQP.new('stream.logs.app', log_exchange)

      queue = AMQ::Client::Queue.new(connection, channel)

      queue.declare(false, false, false, false) do
        logger.info("Persistent queue #{queue.name.inspect} is ready")
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

  def logs_subscribe(routing_key, &block)
    amqp do |connection, channel, fanout, topic|
      logger.io = Logging::IO::Raw.new('stream.logs.cli')
      logger.formatter = Logging::Formatters::JustMessage.new

      exchange = AMQ::Client::Exchange.new(@connection, channel, 'amq.topic', :topic)

      queue = AMQ::Client::Queue.new(connection, channel)

      queue.declare(false, false, false, true) do
        logger.info("Server-named queue #{queue.name.inspect} is ready")
      end

      queue.bind(exchange.name, routing_key) do
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
