# frozen_string_literal: true

require 'active_support'
require 'asn_wrapper/subscriber'
require 'spec_helper'

describe AsnWrapper::Subscriber do
  let(:subscriber) do
    Class.new do
      define_method :process do
      end
    end.send(:include, described_class)
  end

  describe 'Subscription' do
    context 'when subscribed' do
      before { subscriber.subscribe_to('backend.fun') }

      it 'processes the event' do
        expect_any_instance_of(subscriber).to receive(:process)
        ActiveSupport::Notifications.instrument('backend.fun', give_me: :ruby)
      end
    end

    context 'when not subscribed' do
      before { subscriber.subscribe_to('backend.fun') }

      it 'does not process the event' do
        expect_any_instance_of(subscriber).not_to receive(:process)
        ActiveSupport::Notifications.instrument('mobile.not_fun', give_me: :ruby)
      end
    end
  end

  describe 'Included methods' do
    describe '.process' do
      before do
        Class.new.send(:include, described_class).subscribe_to('backend.fun')
      end

      context 'when not implemented' do
        it 'raises NotImplementedError' do
          expect do
            ActiveSupport::Notifications.instrument('backend.fun', give_me: :ruby)
          end.to raise_error(NotImplementedError)
        end
      end
    end

    describe '.valid_to_process?' do
      let(:subscriber_instance) { subscriber.new('backend.fun') }
      let(:payload) do
        {
          resource: {
            backend: :rules,
          },
        }
      end
      let(:event) do
        ActiveSupport::Notifications::Event.new('backend.fun',
          Time.now,
          nil,
          nil,
          payload)
      end
      context 'without conditional_on attributes' do
        before { subscriber_instance.event = event }

        it 'returns true' do
          expect(subscriber_instance.valid_to_process?).to be_truthy
        end
      end
      context 'with conditional_on attributes' do
        let(:resource_double) { double(:resource) }

        before { payload[:conditional_on] = [:name] }

        context 'when have previous_changes' do
          before do
            allow(resource_double).to receive_message_chain('previous_changes.keys').and_return([:name])
            payload[:resource] = resource_double
            subscriber_instance.event = event
          end
          it 'returns true' do
            expect(subscriber_instance.valid_to_process?).to be_truthy
          end
        end
        context 'when have no previous_changes' do
          before do
            allow(resource_double).to receive_message_chain('previous_changes.keys').and_return([])
            payload[:resource] = resource_double
            subscriber_instance.event = event
          end
          it 'returns false' do
            expect(subscriber_instance.valid_to_process?).to be_falsey
          end
        end
        context 'when resource does not respond to previous_changes' do
          before { subscriber_instance.event = event }
          it 'returns true' do
            expect(subscriber_instance.valid_to_process?).to be_truthy
          end
        end
      end
    end
  end
end
