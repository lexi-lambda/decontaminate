# Decontaminate [![Gem Version](https://badge.fury.io/rb/decontaminate.svg)](https://badge.fury.io/rb/decontaminate) [![Build Status](https://travis-ci.org/lexi-lambda/decontaminate.svg?branch=0.2.0)](https://travis-ci.org/lexi-lambda/decontaminate)

Decontaminate is a tool for extracting information from large, potentially nested XML documents. It provides a simple Ruby DSL for selecting values from Nokogiri objects and storing the results in JSON-like Ruby hashes and arrays.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'decontaminate'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install decontaminate

## Usage

Decontaminate provides a DSL for creating *decontaminators*, which, when instantiated, accept XML nodes or documents and produce a hash as a result. To start, create a class that inherits from `Decontaminate::Decontaminator`:

```ruby
class MyDecontaminator < Decontaminate::Decontaminator
end
```

If parsing an entire document, you should specify the name of the root element:

```ruby
class MyDecontaminator < Decontaminate::Decontaminator
  self.root = 'User'
end
```

### Scalar Values

To select values from the XML document, use the `scalar` class method:

```ruby
class MyDecontaminator < Decontaminate::Decontaminator
  self.root = 'User'

  scalar 'Name'
  scalar 'Age', type: :integer
  scalar 'DateRegistered', key: 'registered_at'
end
```

This might produce a result like the following:

```ruby
=> MyDecontaminator.new(xml_document).as_json
{
  'name' => 'Jane Smith',
  'age' => 28,
  'registered_at' => '2013-08-16T20:51:34.236Z'
}
```

The first argument to `scalar` is the name of the node to extract data from. In fact, this can be any XPath string relative to the document root. By default, the resulting JSON key is inferred from the provided path, but it can also be overridden with the `key:` argument. Additionally, the type of the scalar can be specified with the `type:` argument, which defaults to `:string`.

Attributes can be specified with XPath syntax by prepending an `@` sign:

```ruby
scalar '@id', type: :integer
```

#### Scalar Transformers

In addition to customization of the parser using the `type:` keyword argument, `scalar` can be provided with a block that will allow custom transformation of the value. It will be supplied with the value as parsed according to the provided type, and the return value will be the result stored in the output.

```ruby
scalar 'RatingPercentage', key: 'rating_ratio', type: :float do |percentage|
  percentage && percentage / 100.0
end
```

Transformer blocks are evaluated in the context of the decontaminator instance, so instance methods can be called. Additionally, it is possible to call instance methods as transformers directly without needing to pass a block by passing the name of the method as the `transformer:` keyword argument.

```ruby
scalar 'RatingPercentage',
       key: 'rating_ratio',
       type: :float,
       transformer: :percentage_to_ratio

def percentage_to_ratio(percentage)
  percentage && percentage / 100.0
end
```

### Nested Values

It's also possible to specify nested or even deeply nested hashes with the `hash` class method:

```ruby
hash 'UserProfile', key: 'profile' do
  scalar 'Description'

  hash 'Specialization' do
    scalar 'Area'
    scalar 'Expertise', type: :float
  end
end
```

The `hash` method accepts a block, which works just like the class body, but all paths are scoped to the path passed to `hash`. The `key` argument is optional, just like with `scalar`.

Sometimes it may be useful to create an additional hash in the output as an organizational tool, even though there is no equivalent nesting in the input XML. In this case, the XPath argument may be omitted, specifying only `key:`.

```ruby
hash key: 'info' do
  scalar 'Email'
end
```

This will fetch a value from the `Email` node on the root, but it will be stored in a property within a separate hash, keyed in the result with `'info'`.

### Array Data

In addition to the `scalar` and `hash` methods, there are plural forms which allow parsing and extracting data that appears many times within a single document. These are named `scalars` and `hashes`, respectively. They work much like their singular counterparts, but the provided path should match multiple elements.

For example, given the following decontaminator:

```ruby
class ArticlesDecontaminator < Decontaminate::Decontaminator
  hashes 'Articles' do
    scalar 'Name'
    scalars 'Tags'
  end
end
```

And given the following XML document:

```xml
<Articles>
  <Article>
    <Name>Article A</Name>
    <Tags>
      <Tag>News</Tag>
      <Tag>Technology</Tag>
    </Tags>
  </Article>
  <Article>
    <Name>Article B</Name>
    <Tags>
      <Tag>Sports</Tag>
      <Tag>Recreation</Tag>
    </Tags>
  </Article>
</Articles>
```

The resulting object will have the following structure:

```ruby
{
  'articles' => [
    {
      'name' => 'Article A',
      'tags' => ['News', 'Technology']
    },
    {
      'name' => 'Article B',
      'tags' => ['Sports', 'Recreation']
    }
  ]
}
```

There are some special things to note in the above example:

  - **The name of the individual elements is inferred from the parent key.**

    In both cases, the parent element was the plural form of its children (`Articles`/`Article` and `Tags`/`Tag`). Since this is common, the plural forms automatically perform this name inference.

    Since this behavior is sometimes unwanted, it can be disabled by passing the path as an explicit `path:` keyword argument.

    ```ruby
    scalars path: 'Tags/TagName', key: 'tags' # Performs no name inference
    ```

  - **No `root` element was specified since the root element is a plural.**

    When using name inference for a plural element at the root, specifying the root element is an error. By using the explicit `path:` form mentioned above, `root` could still be specified.

    ```ruby
    self.root = 'Articles'
    hashes path: 'Article', key: 'articles' do; ...; end
    ```

### Tuple Data

Complementing `scalar` and `hash` is `tuple`, which accepts multiple paths and returns a fixed-length array containing an element for each path.

```ruby
tuple ['Height/text()', 'Height/@units'], key: 'height_with_units'
```

The `tuple` method is most useful when supplied with a block, which works like `scalar`'s value transformer, but is supplied with an argument for each path. This allows values to be parsed from multiple values in the source document.

```ruby
tuple ['Height/text()', 'Height/@units'], key: 'height_cm' do |height, units|
  convert_units height.to_f, from: units, to: 'cm'
end
```

Tuples also support the shorthand `transformer:` argument that `scalar` and `scalars` support.

### Flattening nested data

Since source data is sometimes more nested than is desired, the `with` method is a helper for scoping decontamination directives to a given XML element without increasing the nesting depth of the resulting object. Like `hash`, it accepts an XPath and a block, but the attributes created from within the block will not be wrapped in a hash.

```ruby
with 'Some/Nested/Data' do
  scalar 'Value'
end
```

There is no plural form for `with` since it would, by necessity, create duplicate keys.
