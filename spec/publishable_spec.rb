# frozen_string_literal: true

require 'active_support'
require 'active_record'
require 'asn_wrapper/publishable'
require 'spec_helper'

def event_for(notification)
  event = nil
  subscription = ActiveSupport::Notifications.subscribe(notification) do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
  end

  yield

  ActiveSupport::Notifications.unsubscribe(subscription)

  event
end

describe AsnWrapper::Publishable do
  class HappyUnicorn < ActiveRecord::Base
    include AsnWrapper::Publishable
    self.table_name = 'happy_unicorns'
  end

  subject { HappyUnicorn }

  before(:all) do
    conn = { adapter: "sqlite3", database: ":memory:" }
    ActiveRecord::Base.establish_connection(conn)
    connection = ActiveRecord::Base.connection
    connection.create_table(:happy_unicorns) do |t|
      t.string(:name)
      t.timestamps
    end
  end

  after(:all) do
    connection = ActiveRecord::Base.connection
    connection.drop_table(:happy_unicorns)
  end

  describe 'event construction' do
    let(:resource) { subject.new }
    let(:payload) do
      {
        resource: resource,
        some: [:more, :args],
      }
    end
    let(:event_name) { "hunt_em_all" }

    it 'detects the event namespace correctly' do
      expect(ActiveSupport::Notifications)
        .to receive(:instrument)
        .with("#{subject.to_s.underscore}.#{event_name}", any_args)
      subject._broadcast_proc_.call(resource, event_name, payload)
    end

    it 'constructs the payload with args' do
      expect(ActiveSupport::Notifications)
        .to receive(:instrument)
        .with("#{subject.to_s.underscore}.#{event_name}", payload)
      subject._broadcast_proc_.call(resource, event_name, payload)
    end
  end

  describe 'AR callback methods' do
    let!(:resource) { subject.create(name: 'Fluffy') }

    context '.attach_to_update_commit' do
      let(:event_name) { 'happy_unicorn.test_record_update' }
      let(:payload) do
        { resource: resource, conditional_on: [:name] }
      end

      before(:all) { HappyUnicorn.send(:attach_to_update_commit, 'test_record_update', conditional_on: [:name]) }

      it 'instruments correct event' do
        expect(ActiveSupport::Notifications).to receive(:instrument).with(event_name, payload)
        resource.touch
      end

      it 'instruments correct payload' do
        event = event_for(event_name) { resource.update(name: 'Dolly') }
        expect(event.payload[:resource]).to eql(resource)
      end
    end

    context '.attach_to_create_commit' do
      before(:all) { HappyUnicorn.send(:attach_to_create_commit, 'test_record_create') }

      let(:event_name) { 'happy_unicorn.test_record_create' }

      it 'instruments correct event' do
        expect(ActiveSupport::Notifications).to receive(:instrument).with(event_name, any_args)
        subject.create(name: 'Dolly')
      end

      it 'instruments correct payload' do
        event = event_for('happy_unicorn.test_record_create') { subject.create(name: 'Dolly') }
        expect(event.payload[:resource]).to eql(subject.last)
      end
    end

    context '.attach_to_destroy_commit' do
      let(:event_name) { 'happy_unicorn.test_record_destroy' }

      before(:all) { HappyUnicorn.send(:attach_to_destroy_commit, 'test_record_destroy') }

      it 'instruments correct event' do
        expect(ActiveSupport::Notifications).to receive(:instrument).with(event_name, any_args)
        resource.destroy
      end

      it 'instruments correct payload' do
        event = event_for(event_name) { resource.destroy }
        expect(event.payload[:resource]).to eql(resource)
      end
    end

    describe '.attach_to' do
      let(:event_name) { 'happy_unicorn.test_record_commit' }

      before(:all) { HappyUnicorn.send(:attach_to, 'test_record_commit') }

      context 'create' do
        it 'instruments correct event' do
          event = event_for('happy_unicorn.test_record_commit') { HappyUnicorn.create(name: 'Corny') }
          expect(event.name).to eql(event_name)
          expect(event.payload[:resource]).to eql(HappyUnicorn.last)
        end
      end

      context 'update' do
        let!(:dolly) { HappyUnicorn.create(name: 'Dolly') }

        it 'instruments correct event' do
          event = event_for('happy_unicorn.test_record_commit') { dolly.update(name: 'Polly') }
          expect(event.name).to eql(event_name)
          expect(event.payload[:resource]).to eql(dolly)
          expect(event.payload[:resource].name).to eql('Polly')
        end
      end

      context 'destroy' do
        let!(:dolly) { HappyUnicorn.create(name: 'Dolly') }

        it 'instruments correct event' do
          event = event_for('happy_unicorn.test_record_commit') { dolly.destroy }
          expect(event.name).to eql(event_name)
          expect(event.payload[:resource]).to eql(dolly)
        end
      end
    end
  end
end
