# frozen_string_literal: true

module AsnWrapper
  module Subscriber
    extend ActiveSupport::Concern
    extend self

    included do
      attr_reader :event_name
      attr_accessor :event
    end

    def initialize(event_name)
      @event_name = event_name
    end

    def call(event_name, *args)
      handler = self.class.new(event_name)
      event = ActiveSupport::Notifications::Event.new(event_name, *args)
      handler.public_send("event=", event)
      handler.process
    end

    def valid_to_process?
      return false if event.payload[:exception]
      conditional_keys = event.payload[:conditional_on]
      return true unless conditional_keys && resource.respond_to?(:previous_changes)
      (conditional_keys & resource.previous_changes.keys).any? && (block_given? ? yield : true)
    end

    def resource
      @resource ||= event.payload.fetch(:resource)
    end

    def process
      raise NotImplementedError, ":#{__method__} method must be implemented in the including class"
    end

    class_methods do
      def subscribe_to(event_name)
        handler = new(event_name)
        ActiveSupport::Notifications.subscribe(event_name, handler)
      end
    end
  end
end
