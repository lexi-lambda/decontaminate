require 'active_support/inflector'

require_relative 'decoder/array'
require_relative 'decoder/child_node_proxy'
require_relative 'decoder/hash'
require_relative 'decoder/scalar'

module Decontaminate
  # Decontaminate::Decontaminator is the base class for creating XML extraction
  # parsers. A DSL is exposed via class methods to allow specifying how the XML
  # should be parsed.
  class Decontaminator
    class << self
      attr_accessor :root
      attr_reader :decoders

      def inherited(subclass)
        subclass.instance_eval do
          @root = '.'
          @decoders = {}
        end
      end

      def scalar(xpath, type: :string, key: infer_key(xpath))
        add_decoder key, Decontaminate::Decoder::Scalar.new(xpath, type)
      end

      def scalars(xpath = nil, path: nil, type: :string, key: nil)
        resolved_path = path || infer_plural_path(xpath)
        key ||= infer_key(path || xpath)

        singular = Decontaminate::Decoder::Scalar.new('.', type)
        decoder = Decontaminate::Decoder::Array.new(resolved_path, singular)

        add_decoder key, decoder
      end

      def hash(xpath = '.', key: infer_key(xpath), &body)
        decontaminator = Class.new(Decontaminate::Decontaminator, &body)
        add_decoder key, Decontaminate::Decoder::Hash.new(xpath, decontaminator)
      end

      def hashes(xpath = nil, path: nil, key: nil, &body)
        resolved_path = path || infer_plural_path(xpath)
        key ||= infer_key(path || xpath)

        decontaminator = Class.new(Decontaminate::Decontaminator, &body)
        singular = Decontaminate::Decoder::Hash.new('.', decontaminator)
        decoder = Decontaminate::Decoder::Array.new(resolved_path, singular)

        add_decoder key, decoder
      end

      def with(xpath, &body)
        this = self
        decontaminator = Class.new(Decontaminate::Decontaminator)

        decontaminator.instance_eval do
          define_singleton_method :add_decoder do |key, decoder|
            proxy = Decontaminate::Decoder::ChildNodeProxy.new(xpath, decoder)
            this.add_decoder key, proxy
          end
        end

        decontaminator.class_eval(&body)
      end

      def add_decoder(key, decoder)
        fail "Decoder already registered for key #{key}" if decoders.key? key
        decoders[key] = decoder
      end

      def infer_key(xpath)
        xpath.delete('@').underscore
      end

      def infer_plural_path(xpath)
        xpath + '/' + xpath.split('/').last.singularize
      end
    end

    attr_reader :xml_node

    def initialize(xml_node)
      @xml_node = xml_node
    end

    def as_json
      acc = {}

      root_node = xml_node.at_xpath root
      decoders.each do |key, decoder|
        acc[key] = decoder.decode root_node
      end

      acc
    end

    private

    def decoders
      self.class.decoders
    end

    def root
      self.class.root
    end
  end
end
