require 'active_support/inflector'

require_relative 'decoder/array'
require_relative 'decoder/child_node_proxy'
require_relative 'decoder/hash'
require_relative 'decoder/scalar'
require_relative 'decoder/tuple'

module Decontaminate
  # {Decontaminate::Decontaminator} is the base class for creating XML
  # extraction parsers. A DSL is exposed via class methods to allow specifying
  # how the XML should be parsed.
  class Decontaminator
    class << self
      # An attribute that controls what the base element should be for all XPath
      # queries against the provided XML node.
      attr_accessor :root

      # @private
      attr_reader :decoders

      # @private
      def inherited(subclass)
        subclass.instance_eval do
          @root = '.'
          @decoders = {}
        end
      end

      # @!group DSL Directives

      # Produces a singular scalar value in the resulting JSON, which can be
      # a string, an integer, a float, or a boolean, depending on the value
      # provided for the +type+ argument. The default is +:string+. If the node
      # pointed to by +xpath+ is plain text or an attribute value, then that
      # value will be used directly. Otherwise, the node's text will be used
      # when parsing the scalar value.
      #
      # The +key+ argument is optional. If it is not provided, its value will be
      # inferred from +xpath+ using {infer_key}.
      #
      # If the +xpath+ does not point to an element, the result will be +nil+.
      #
      # The result may be customized by either passing a block or providing a
      # value for the +transformer+ argument (passing both is an error). If
      # +transformer+ is provided, then the instance method with the same name
      # is called with the resulting value, and the method's return value is
      # what is included in the resulting JSON. If a block is provided, it is
      # called with the resulting value in the context of the instance (so
      # +self+ points to an instance of the decontaminator), and its return
      # value is what is included in the resulting JSON.
      #
      # @param xpath [String] A relative XPath string that points to the scalar
      #   value
      # @param type [Symbol] One of either +:string+, +:integer+, +:float+, or
      #   +:boolean+
      # @param key [String] The key for the value in the resulting JSON
      # @param transformer [Symbol] A symbol with the name of an instance method
      #   used to transform the result
      # @param block A block used to transform the result
      def scalar(xpath,
                 type: :string,
                 key: infer_key(xpath),
                 transformer: nil,
                 &block)
        block ||= self_proc_for_method transformer
        add_decoder key, Decontaminate::Decoder::Scalar.new(xpath, type, block)
      end

      # The plural version of {scalar}. Produces an array of scalars for the
      # given key in the resulting JSON. If the element path is specified using
      # the +xpath+ argument, then the individual elements are inferred using
      # {infer_plural_path}. Otherwise, if the elements are specified using the
      # +path+ argument, no inference is performed, and the path must return a
      # set of multiple elements.
      #
      # If +xpath+ is provided, but the parent element does not exist, the
      # result will be an empty array, not +nil+.
      #
      # @param xpath [String] A relative XPath string that points to a parent
      #   element containing singular values (mutually exclusive with +path+)
      # @param path [String] A relative XPath string that points to the singular
      #   values (mutually exclusive with +xpath+)
      # @param type [Symbol] One of either +:string+, +:integer+, +:float+, or
      #   +:boolean+
      # @param key [String] The key for the value in the resulting JSON
      # @param transformer [Symbol] A symbol with the name of an instance method
      #   used to transform the result
      # @param block A block used to transform the result
      def scalars(xpath = nil,
                  path: nil,
                  type: :string,
                  key: nil,
                  transformer: nil,
                  &block)
        resolved_path = path || infer_plural_path(xpath)
        key ||= infer_key(path || xpath)
        block ||= self_proc_for_method transformer

        singular = Decontaminate::Decoder::Scalar.new('.', type, block)
        decoder = Decontaminate::Decoder::Array.new(resolved_path, singular)

        add_decoder key, decoder
      end

      # Like {scalar} but using multiple +paths+. By default, this will produce
      # a fixed-length array in the resulting JSON containing an element for
      # each path.
      #
      # This is especially useful when combined with a block or transformer,
      # since the result can be a value computed from the individual element
      # values. When the block or transformer method is called, it is provided
      # a _separate_ argument for _each_ value in the tuple.
      #
      # @param paths [Array<String>] An array of relative XPath strings that
      #   each point to a scalar value
      # @param key [String] The key for the value in the resulting JSON
      # @param type [Symbol] One of either +:string+, +:integer+, +:float+, or
      #   +:boolean+
      # @param transformer [Symbol] A symbol with the name of an instance method
      #   used to transform the result
      # @param block A block used to transform the result
      def tuple(paths,
                key:,
                type: :string,
                transformer: nil,
                &block)
        block ||= self_proc_for_method transformer

        scalar = Decontaminate::Decoder::Scalar.new('.', type, nil)
        decoder = Decontaminate::Decoder::Tuple.new(paths, scalar, block)

        add_decoder key, decoder
      end

      # Produces a hash in the resulting JSON with values determined by the body
      # of the provided block. The {hash} directive allows for logical grouping
      # of values by nesting them within separate hash structures. The body of
      # the provided block works just like the surrounding context---directives
      # such as {scalar}, {tuple}, and even {hash} may be further nested within
      # the hash body.
      #
      # The +xpath+ argument is optional if +key+ is provided. If +xpath+ is
      # provided, it will scope the block to the element referenced by +xpath+
      # like {with}. In fact, providing +xpath+ works exactly the same as
      # wrapping the body of {hash} with a {with} directive.
      #
      # The +key+ argument is optional if +xpath+ is provided. If +key+ is not
      # provided, its value will be inferred from +xpath+ using {infer_key}.
      #
      # If the +xpath+ does not point to an element, the result will be +nil+.
      #
      # @param xpath [String] A relative XPath string that points to the parent
      #   node for all values within the hash
      # @param key [String] The key for the value in the resulting JSON
      # @param body A block that includes directives that specify the contents
      #   of the hash
      def hash(xpath = '.', key: infer_key(xpath), &body)
        decontaminator = Class.new(class_to_inherit_from, &body)
        add_decoder key, Decontaminate::Decoder::Hash.new(xpath, decontaminator)
      end

      # The plural version of {hash}. Produces an array of hashes for the given
      # key in the resulting JSON. If the element path is specified using the
      # +xpath+ argument, then the individual elements are inferred using
      # {infer_plural_path}. Otherwise, if the elements are specified using the
      # +path+ argument, no inference is performed, and the path must return a
      # set of multiple elements.
      #
      # If +xpath+ is provided, but the parent element does not exist, the
      # result will be an empty array, not +nil+.
      #
      # @param xpath [String] A relative XPath string that points to a parent
      #   element containing singular values (mutually exclusive with +path+)
      # @param path [String] A relative XPath string that points to the singular
      #   values (mutually exclusive with +xpath+)
      # @param key [String] The key for the value in the resulting JSON
      # @param body A block that includes directives that specify the contents
      #   of the hash
      def hashes(xpath = nil, path: nil, key: nil, &body)
        resolved_path = path || infer_plural_path(xpath)
        key ||= infer_key(path || xpath)

        decontaminator = Class.new(class_to_inherit_from, &body)
        singular = Decontaminate::Decoder::Hash.new('.', decontaminator)
        decoder = Decontaminate::Decoder::Array.new(resolved_path, singular)

        add_decoder key, decoder
      end

      # Scopes all nested directives to the node referenced by the +xpath+
      # argument. Unlike other directives, {with} does not produce any value in
      # the resulting JSON. Instead, it just adjusts all nested paths so that
      # they are relative to the node referenced by +xpath+.
      #
      # @param xpath [String] A relative XPath string that points to a single
      #   node
      # @param body A block that includes directives that are scoped to the
      #   referenced node
      def with(xpath, &body)
        this = self
        decontaminator = Class.new(class_to_inherit_from)

        decontaminator.instance_eval do
          # proxy add_decoder to the parent class
          define_singleton_method :add_decoder do |key, decoder|
            proxy = Decontaminate::Decoder::ChildNodeProxy.new(xpath, decoder)
            this.add_decoder key, proxy
          end

          # also, don't let subclasses inherit from this; they would also pick
          # up the overridden add_decoder method
          define_singleton_method :class_to_inherit_from do
            this
          end
        end

        decontaminator.class_eval(&body)
      end

      # @!endgroup

      # Registers an XML decoder under the given key. This method is called by
      # all of the DSL directives when registering a decoder into the internal
      # list of decoders. It can be overridden by subclasses to customize how
      # adding decoders works (this is done anonymously by {with}).
      #
      # @param key [String] The key the decoder will produce in the resulting
      #   JSON
      # @param decoder [Decontaminate::Decoder] A decoder instance used to
      #   produce the result value
      def add_decoder(key, decoder)
        fail "Decoder already registered for key #{key}" if decoders.key? key
        decoders[key] = decoder
      end

      # Infers the name of a key for use in a JSON object from an XPath query
      # string. This is used by the DSL directives to infer a key when one is
      # not provided. By default, it strips a leading +@+ sign, removes all
      # leading or trailing underscores, then converts the string to an
      # underscore-separated string using {ActiveSupport::Inflector#underscore}.
      #
      # @param xpath [String] An XPath query string
      # @return [String] A key for use in a JSON object
      def infer_key(xpath)
        xpath.delete('@').gsub(/^_+|_+$/, '').underscore
      end

      # Infers that path for singular elements from an XPath string referring to
      # a plural parent element. This is used by {scalars} and {hashes} to infer
      # their singular elements. By default, it finds the last path element,
      # splitting the string on forward-slash characters, converts it to a
      # singular by using {ActiveSupport::Inflector#singularize}, and appends
      # the result to the whole path.
      #
      # @param xpath [String] An XPath query string
      # @return [String] An inferred path to the singular elements
      def infer_plural_path(xpath)
        xpath + '/' + xpath.split('/').last.singularize
      end

      private

      def class_to_inherit_from
        self
      end

      def self_proc_for_method(sym)
        sym && proc { |*args| send sym, *args }
      end
    end

    attr_reader :xml_node

    # Instantiates a decontaminator with a Nokogiri XML node or document.
    #
    # @param xml_node [Nokogiri::XML::Node] The XML node or document to
    #   decontaminate
    def initialize(xml_node, instance: nil)
      @xml_node = xml_node
      @instance = instance
    end

    # Retrieves the decontaminated JSON representation of the given XML node.
    #
    # @return [Hash] The decontaminated JSON object
    def as_json
      acc = {}

      root_node = xml_node && xml_node.at_xpath(root)
      decoders.each do |key, decoder|
        acc[key] = decoder.decode instance, root_node
      end

      acc
    end

    private

    # The canonical instance that all blocks should run within. Child
    # (anonymous) decontaminators should delegate to the parent.
    def instance
      @instance || self
    end

    def decoders
      self.class.decoders
    end

    def root
      self.class.root
    end
  end
end
