# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'decontaminate/version'

Gem::Specification.new do |spec|
  spec.name          = 'decontaminate'
  spec.version       = Decontaminate::VERSION
  spec.authors       = ['Alexis King']
  spec.email         = ['lexi.lambda@gmail.com']

  spec.summary       = 'Convert XML to JSON with a DSL'
  spec.homepage      = 'https://github.com/lexi-lambda/decontaminate'
  spec.licenses      = ['ISC']

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.1'

  spec.add_runtime_dependency 'activesupport', '~> 4.2'
  spec.add_runtime_dependency 'nokogiri', '~> 1.6'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'pry', '~> 0.10.3'
  spec.add_development_dependency 'pry-byebug', '~> 3.2'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.3'
  spec.add_development_dependency 'yard', '~> 0.8.7'
end
