#!/usr/bin/env ruby
# encoding: utf-8

# Usage:
# ./bin/send.rb bcn.unreasonable_at_sea '{"id": 1}'

require_relative '../lib/env'

EM.run do
  Stream.new do |app|
    app.logger.io = Logging::IO::Null.new('stream.logs.cli')

    app.amqp do |connection, channel|
      name = "stream.ideas.#{ARGV.shift}"
      exchange = AMQ::Client::Exchange.new(connection, channel, name, :fanout)

      # In case it doesn't exist yet, convenience helper.
      exchange.declare(false, false, false, true) do
        logger.info("Temporary exchange #{exchange.name.inspect} is ready")
      end

      exchange.publish(ARGV.join(" "))
      connection.disconnect { EM.stop }
    end
  end
end
