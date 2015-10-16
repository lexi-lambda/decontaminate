require 'bundler/setup'

require 'pry'
require 'rspec'

require 'decontaminate'
require 'nokogiri'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
