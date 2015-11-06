# -*- encoding: utf-8 -*-
$:.push File.expand_path(File.join('..', 'lib'), __FILE__)
require_relative 'lib/simple_doi/version'

Gem::Specification.new do |spec|
  spec.name          = 'simple_doi'
  spec.version       = SimpleDOI::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = %w(Michael Berkowski)
  spec.email         = %w(libwebdev@umn.edu)
  spec.homepage      = ''
  spec.summary       = 'DOI extraction and metadata retrieval library'
  spec.description   = 'Provides classes which attempt to locate DOI identifiers in strings and resolve them to their target URLs or retrieve XML or JSON metadata about their target resources'

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- test/*`.split("\n")
  spec.executables   = []
  spec.require_paths = %w(lib)

  spec.add_runtime_dependency 'json'
  spec.add_runtime_dependency 'nokogiri'
  spec.add_development_dependency 'minitest'
end
