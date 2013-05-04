#!/usr/bin/env ruby
# encoding: utf-8

# Use this script to see what has been published.
#
# How it works:
#   It creates a new, auto-deletable queue and binds it on the amq.fanout exchange.
#   Once we interrupt the script, queue is deleted, so everything's published only
#   into the original 'stream.ideas' queue again.

require_relative '../lib/env'

EM.run do
  Stream.new do |app|
    app.logger.io = Logging::IO::Raw.new('stream.logs.cli')
    app.logger.formatter = Logging::Formatters::JustMessage.new

    app.subscribe('inspect.stream.ideas', true) do |payload, header, frame|
      app.logger.write('')
      app.logger.inspect(:payload, payload)
      app.logger.inspect(:header, header.properties)
      app.logger.inspect(:frame, frame.instance_variables.reduce(Hash.new) do |buffer, variable|
        buffer.merge(variable.to_s[1..-1] => frame.instance_variable_get(variable))
      end)
      app.logger.write('')
    end
  end
end
