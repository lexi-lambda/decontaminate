module Decontaminate
  module Decoder
    class Hash
      attr_reader :xpath, :decontaminator

      def initialize(xpath, decontaminator)
        @xpath = xpath
        @decontaminator = decontaminator
      end

      def decode(xml_node)
        child = xml_node.at_xpath xpath
        decontaminator.new(child).as_json
      end
    end
  end
end
