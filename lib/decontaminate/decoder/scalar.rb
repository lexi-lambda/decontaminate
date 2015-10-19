module Decontaminate
  module Decoder
    class Scalar
      attr_reader :xpath, :type, :transformer

      def initialize(xpath, type, transformer)
        @xpath = xpath
        @type = type
        @transformer = transformer
      end

      def decode(this, xml_node)
        value = value_from_xml_node xml_node
        value = this.instance_exec(value, &transformer) if transformer
        value
      end

      private

      def value_from_xml_node(xml_node)
        child = xml_node && xml_node.at_xpath(xpath)
        return unless child

        text = coerce_node_to_text child
        coerce_string_to_type text, type
      end

      def coerce_node_to_text(node)
        if node.is_a?(Nokogiri::XML::Text) || node.is_a?(Nokogiri::XML::Attr)
          node.to_s
        else
          node.at_xpath('text()').to_s
        end
      end

      def coerce_string_to_type(str, type)
        case type
        when :string
          str
        when :integer
          str.to_i
        when :float
          str.to_f
        when :boolean
          coerce_string_to_boolean str
        end
      end

      def coerce_string_to_boolean(str)
        str == 'true' || str == '1'
      end
    end
  end
end
