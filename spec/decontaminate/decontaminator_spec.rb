require 'spec_helper'

RSpec.describe Decontaminate::Decontaminator do
  class SampleDecontaminator < Decontaminate::Decontaminator
    self.root = 'Root'

    scalar 'Name'
    scalars 'BadgeIds', type: :integer

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

      hash 'Specialization' do
        scalar 'Area'
      end
    end

    hash 'Privileges' do
      scalar 'IsPaid', key: 'paid', type: :boolean
      scalar 'IsAdmin', key: 'admin', type: :boolean
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
      'info' => {
        'email' => nil
      },
      'badge_ids' => [],
      'profile' => {
        'description' => nil,
        'questions' => []
      },
      'age' => nil,
      'specialization' => nil,
      'privileges' => {
        'paid' => nil,
        'admin' => nil
      }
    )
  end
end
