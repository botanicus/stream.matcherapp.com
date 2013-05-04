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

  def response(env)
    self.app.subscribe do |payload|
      env.stream_send("data: #{payload}\n\n")
    end

    app.logger.inspect([200, {'Content-Type' => 'text/event-stream'}])

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end
end
