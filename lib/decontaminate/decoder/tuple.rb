module Decontaminate
  module Decoder
    class Tuple
      attr_reader :xpaths, :decoder, :transformer

      def initialize(xpaths, decoder, transformer)
        @xpaths = xpaths
        @decoder = decoder
        @transformer = transformer
      end

      def decode(xml_node)
        xml_nodes = xpaths.map { |xpath| xml_node && xml_node.at_xpath(xpath) }
        tuple = xml_nodes.map do |element_node|
          decoder.decode element_node
        end

        tuple = transformer.call(*tuple) if transformer

        tuple
      end
    end
  end
end
