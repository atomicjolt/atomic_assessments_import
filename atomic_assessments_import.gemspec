# frozen_string_literal: true

require_relative "lib/atomic_assessments_import/version"

Gem::Specification.new do |spec|
  spec.name = "atomic_assessments_import"
  spec.version = AtomicAssessmentsImport::VERSION
  spec.authors = ["Sean Collings", "Matt Petro"]
  spec.email = ["support@atomicjolt.com"]

  spec.summary = "Importer to Convert different formats to AA's import format"
  spec.description = "Importer to Convert different formats to AA's import format"
  spec.homepage = "https://github.com/atomicjolt/atomic_assessments_import"
  spec.required_ruby_version = ">= 3.3.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  spec.add_dependency "activesupport"
  spec.add_dependency "csv"
  spec.add_dependency "mimemagic"
  spec.add_dependency "rubyzip"
end
