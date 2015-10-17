module Decontaminate
  module Decoder
    class Array
      attr_reader :xpath, :decoder

      def initialize(xpath, decoder)
        @xpath = xpath
        @decoder = decoder
      end

      def decode(xml_node)
        children = xml_node && xml_node.xpath(xpath)
        return [] unless children
        children.map do |child|
          decoder.decode child
        end
      end
    end
  end
end
