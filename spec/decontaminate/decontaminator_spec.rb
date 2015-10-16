require 'spec_helper'

RSpec.describe Decontaminate::Decontaminator do
  class SampleDecontaminator < Decontaminate::Decontaminator
    self.root = 'Root'

    scalar 'Name'
    scalars 'BadgeIds', type: :integer

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
  end

  let(:xml_document) do
    fixture = File.read 'spec/support/fixtures/sample_document.xml'
    Nokogiri::XML fixture
  end

  it 'decodes XML to JSON' do
    json = SampleDecontaminator.new(xml_document).as_json
    expect(json).to eq(
      'name' => 'John Smith',
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
      }
    )
  end
end
