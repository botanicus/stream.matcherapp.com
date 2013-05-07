#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler'
Bundler.setup

require 'goliath'
require_relative 'lib/goliath_hacks'

require_relative 'lib/env'

class SSE < Goliath::API
  def app
    @app ||= Stream.new
  end

  # Subscribe to stream of ideas for given location.
  #
  # stream.ideas.bcn.unreasonable_at_sea (fanout)
  #   -> Queue for client 1
  #   -> Queue for client 2
  def response(env)
    exchange_name = 'stream.ideas.bcn.unreasonable_at_sea'

    self.app.amqp do |connection, channel|
      exchange = AMQ::Client::Exchange.new(connection, channel, exchange_name, :fanout)

      exchange.declare(false, false, false, true) do
        logger.info("Temporary exchange #{exchange.name.inspect} is ready")
      end

      queue = AMQ::Client::Queue.new(connection, channel)

      queue.declare(false, false, false, true) do
        logger.info("Temporary queue #{queue.name.inspect} is ready")
      end

      queue.bind(exchange.name) do
        logger.info("Queue #{queue.name} is now bound to #{exchange.name}")
      end

      self.app.subscribe(exchange) do |payload|
        app.logger.info("Chunk: #{payload.inspect}")
        env.stream_send("data: #{payload}\n\n")
      end
    end

    app.logger.inspect([200, {'Content-Type' => 'text/event-stream'}])

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end
end
