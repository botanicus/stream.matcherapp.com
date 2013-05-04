#!/usr/bin/env ruby
# encoding: utf-8

# Usage:
# ./bin/send.rb '{"id": 1}'

require_relative '../lib/env'

EM.run do
  Stream.new do |app|
    app.logger.io = Logging::IO::Null.new('stream.logs.cli')

    app.amqp do |connection, channel, exchange|
      exchange.publish(ARGV.join(" "))
      connection.disconnect { EM.stop }
    end
  end
end
