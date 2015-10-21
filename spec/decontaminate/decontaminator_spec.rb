require 'spec_helper'

RSpec.describe Decontaminate::Decontaminator do
  class SampleDecontaminator < Decontaminate::Decontaminator
    self.root = 'Root'

    scalar 'Name'
    scalars 'BadgeIds', type: :integer

    scalar 'RatingPercentage', key: 'rating', type: :float do |percent|
      percent && percent / 100.0
    end

    scalar 'RatingPercentage',
           key: 'transformed_rating',
           transformer: :instance_transformer

    hash key: 'info' do
      scalar 'Email'
    end

    hash 'UserProfile', key: 'profile' do
      scalar 'Description'

      hashes 'Questions' do
        scalar '@Id', type: :integer
        scalar 'Title'
      end
    end

    with 'Attributes' do
      scalar 'Age', type: :integer
      tuple ['Height/text()', 'Height/@units'], key: 'height' do |value, units|
        value && units && "#{value} #{units}"
      end

      hash 'Specialization' do
        scalar 'Area'
      end
    end

    hash 'Privileges' do
      scalar 'IsPaid', key: 'paid', type: :boolean
      scalar 'IsAdmin', key: 'admin', type: :boolean
    end

    def instance_transformer(value)
      value && "transformed: #{value}"
    end
  end

  let(:xml_document) do
    fixture = File.read 'spec/support/fixtures/sample_document.xml'
    Nokogiri::XML fixture
  end

  let(:empty_xml_document) do
    Nokogiri::XML '<Root></Root>'
  end

  it 'decodes XML to JSON' do
    json = SampleDecontaminator.new(xml_document).as_json
    expect(json).to eq(
      'name' => 'John Smith',
      'rating' => 0.85,
      'transformed_rating' => 'transformed: 85',
      'info' => {
        'email' => 'jsmith@example.com'
      },
      'badge_ids' => [1, 3, 7],
      'profile' => {
        'description' => 'Some user.',
        'questions' => [
          { 'id' => 5, 'title' => 'Question number 5.' },
          { 'id' => 17, 'title' => 'Question number 17.' }
        ]
      },
      'age' => 25,
      'height' => '5.7 ft',
      'specialization' => {
        'area' => 'Engineering'
      },
      'privileges' => {
        'paid' => true,
        'admin' => false
      }
    )
  end

  it 'fills in missing keys with nil' do
    json = SampleDecontaminator.new(empty_xml_document).as_json
    expect(json).to eq(
      'name' => nil,
      'rating' => nil,
      'transformed_rating' => nil,
      'info' => {
        'email' => nil
      },
      'badge_ids' => [],
      'profile' => {
        'description' => nil,
        'questions' => []
      },
      'age' => nil,
      'height' => nil,
      'specialization' => {
        'area' => nil
      },
      'privileges' => {
        'paid' => nil,
        'admin' => nil
      }
    )
  end

  describe '.infer_key' do
    def infer_key(*args)
      Decontaminate::Decontaminator.infer_key(*args)
    end

    it 'converts camel case to underscores' do
      expect(infer_key 'FooBarBaz').to eq 'foo_bar_baz'
    end

    it 'strips a leading @ sign' do
      expect(infer_key '@FooBarBaz').to eq 'foo_bar_baz'
    end

    it 'strips leading and trailing underscores after @ removal' do
      cases = %w(
        _FooBarBaz __FooBarBaz FooBarBaz_ FooBarBaz__ __FooBarBaz_ _FooBarBaz__
        __FooBarBaz__ @_FooBarBaz @__FooBarBaz @FooBarBaz_ @FooBarBaz__
        @__FooBarBaz_ @_FooBarBaz__ @__FooBarBaz__
      )

      expect(cases.map { |c| infer_key c }).to all eq 'foo_bar_baz'
    end
  end
end
