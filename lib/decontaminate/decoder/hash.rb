module Decontaminate
  module Decoder
    class Hash
      attr_reader :xpath, :decontaminator

      def initialize(xpath, decontaminator)
        @xpath = xpath
        @decontaminator = decontaminator
      end

      def decode(this, xml_node)
        child = xml_node && xml_node.at_xpath(xpath)
        decontaminator.new(child, instance: this).as_json
      end
    end
  end
end
