# frozen_string_literal: true

module AsnWrapper
  module Publishable
    extend ActiveSupport::Concern
    extend self

    included do
      mattr_accessor :_namespace_, :_broadcast_proc_
      self._namespace_ = name.underscore
      self._broadcast_proc_ = -> (model, event, args) do
        event_name = "#{_namespace_}.#{event}"
        payload = { resource: model }
        broadcast(event_name, payload.merge(args))
      end
    end

    def broadcast(event_name, args = {})
      _broadcast_proc_.call(self, event_name, args)
    end

    def raw_broadcast(event_name, event = {})
      self.class.broadcast(event_name, event)
    end

    class_methods do
      def broadcast(event_name, event = {})
        ActiveSupport::Notifications.instrument(event_name, event) { yield if block_given? }
      end

      def attach_to(event, **args)
        after_commit(**args) do |model|
          _broadcast_proc_.call(model, event, args)
        end
      end

      def attach_to_create_commit(event, **args)
        after_create_commit(**args) do |model|
          _broadcast_proc_.call(model, event, args)
        end
      end

      def attach_to_update_commit(event, **args)
        after_update_commit(**args) do |model|
          _broadcast_proc_.call(model, event, args)
        end
      end

      def attach_to_destroy_commit(event, **args)
        after_destroy_commit(**args) do |model|
          _broadcast_proc_.call(model, event, args)
        end
      end
    end
  end
end
