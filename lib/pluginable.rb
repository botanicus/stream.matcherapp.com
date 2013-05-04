# encoding: utf-8

module Pluginable
  def self.included(base)
    case self.class
    when Class
      method = :class_eval
    when Module
      method = :module_eval
    when Object
      method = :instance_eval
    end

    define_method(:eval_method) do
      method
    end
  end

  def self.extended(base)
    self.included(base)
  end

  def plugin(label, &block)
    # require_relative path_to_require # TODO: just require
    self.send(self.eval_method, &block)
  end
end
