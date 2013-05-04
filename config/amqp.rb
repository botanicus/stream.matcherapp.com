# encoding: utf-8

Stream.set(:amqp) do |config|
  config.adapter   = 'eventmachine'
  config.vhost     = 'matcherapp.com'
  config.user      = 'matcherapp.com'
  config.password  = 'ae28cd87adb5c385117f89e9bd452d18'
end
