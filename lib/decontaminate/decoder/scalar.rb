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
        text = child && coerce_node_to_text(child)

        case type
        when :string
          text
        when :integer
          text && text.to_i
        when :float
          text && text.to_f
        when :boolean
          coerce_string_to_boolean text
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

      def coerce_string_to_boolean(str)
        str == 'true' || str == '1'
      end
    end
  end
end
