module Decontaminate
  module Decoder
    class Scalar
      attr_reader :xpath, :type

      def initialize(xpath, type)
        @xpath = xpath
        @type = type
      end

      def decode(xml_node)
        child = xml_node.at_xpath xpath
        text = coerce_node_to_text child

        return unless text

        case type
        when :string
          text
        when :integer
          text.to_i
        when :float
          text.to_f
        end
      end

      private

      def coerce_node_to_text(node)
        if node.is_a?(Nokogiri::XML::Text) || node.is_a?(Nokogiri::XML::Attr)
          node.to_s
        else
          node.at_xpath('text()').to_s
        end
      end
    end
  end
end
