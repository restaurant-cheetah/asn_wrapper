# frozen_string_literal: true

require File.expand_path("../lib/asn_wrapper/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "asn_wrapper"
  s.version     = AsnWrapper::VERSION
  s.platform    = Gem::Platform::RUBY
  s.licenses    = %w(MIT)
  s.authors     = ["Anton Magids"]
  s.email       = ["evnomadx@gmail.com"]
  s.homepage    = "https://github.com/restaurant-cheetah/asn_wrapper"
  s.summary     = "ActiveSupport Notifications Wrapper"
  s.description = "Include Publishable module -> create Subscriber -> Subscribe -> Profit"
  s.post_install_message = "Wrap & Notify"

  all_files = %x(git ls-files).split("\n")
  test_files = %x(git ls-files -- {test,spec,features}/*).split("\n")

  s.files         = all_files - test_files
  s.test_files    = test_files
  s.require_paths = %w(lib)

  s.required_ruby_version = ">= 1.9.2"
  s.add_runtime_dependency "activerecord", ">= 5.2.0"
  s.add_runtime_dependency "activesupport", ">= 5.2.0"
end