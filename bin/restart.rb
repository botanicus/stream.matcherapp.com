#!/usr/bin/env ruby
# encoding: utf-8

pid_file = File.expand_path('../../goliath.pid', __FILE__)

begin
  Process.kill('TERM', File.read(pid_file).to_i)
rescue Errno::ENOENT, Errno::ESRCH
end

ARGV.push('--daemonize', '--pid', pid_file)
load File.expand_path('../../app.rb', __FILE__)
