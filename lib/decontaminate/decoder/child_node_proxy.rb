module Decontaminate
  module Decoder
    class ChildNodeProxy
      attr_reader :xpath, :decoder

      def initialize(xpath, decoder)
        @xpath = xpath
        @decoder = decoder
      end

      def decode(xml_node)
        child = xml_node && xml_node.at_xpath(xpath)
        decoder.decode child
      end
    end
  end
end
