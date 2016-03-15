# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'txml_importer/version'

Gem::Specification.new do |spec|
  spec.name          = "txml_importer"
  spec.version       = TxmlImporter::VERSION
  spec.authors       = ["Kevin S. Dias"]
  spec.email         = ["diasks2@gmail.com"]

  spec.summary       = %q{.txml file importer}
  spec.description   = %q{Import the content of a .txml file.}
  spec.homepage      = "https://github.com/diasks2/txml_importer"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_runtime_dependency "libxml-ruby"
  spec.add_runtime_dependency "pretty_strings", "~> 0.6.0"
  spec.add_runtime_dependency "charlock_holmes_bundle_icu", "~> 0.6.9.2"
end
