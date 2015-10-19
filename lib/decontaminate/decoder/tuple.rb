module Decontaminate
  module Decoder
    class Tuple
      attr_reader :xpaths, :decoder, :transformer

      def initialize(xpaths, decoder, transformer)
        @xpaths = xpaths
        @decoder = decoder
        @transformer = transformer
      end

      def decode(this, xml_node)
        xml_nodes = xpaths.map { |xpath| xml_node && xml_node.at_xpath(xpath) }
        tuple = xml_nodes.map do |element_node|
          decoder.decode this, element_node
        end

        tuple = this.instance_exec(*tuple, &transformer) if transformer

        tuple
      end
    end
  end
end
