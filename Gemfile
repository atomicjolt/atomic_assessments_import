# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in atomic_assessments_import.gemspec
gemspec

group :development, :test, :linter do
  gem "byebug"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rspec"
end

group :test do
  gem "rspec"
end

group :ci do
  gem "brakeman"
  gem "pronto"
  gem "pronto-rubocop", require: false
end
