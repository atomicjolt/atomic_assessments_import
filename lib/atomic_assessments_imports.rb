# frozen_string_literal: true

require "active_support/json"
require "mimemagic"
require_relative "atomic_assessments_imports/version"
require_relative "atomic_assessments_imports/csv"
require_relative "atomic_assessments_imports/writer"
require_relative "atomic_assessments_imports/export"

module AtomicAssessmentsImports
  class Error < StandardError; end

  def self.convert(path)
    type = MimeMagic.by_path(path)&.type

    converter =
      case type
      when "text/csv"
        CSV::Converter.new(path)
      else
        raise "Unsupported file type"
      end

    converter.convert
  end
end
