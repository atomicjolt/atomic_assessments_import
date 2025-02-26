# frozen_string_literal: true

require "active_support/all"
require "mimemagic"
require_relative "atomic_assessments_import/version"
require_relative "atomic_assessments_import/csv"
require_relative "atomic_assessments_import/writer"
require_relative "atomic_assessments_import/export"

module AtomicAssessmentsImport
  class Error < StandardError; end

  def self.convert(path)
    type = MimeMagic.by_path(path)&.type

    converter =
      case type
      when "text/csv"
        CSV::Converter.new(path)
      else
        raise ArgumentError, "Unsupported file type"
      end

    converter.convert
  end

  def self.convert_to_aa_format(input_path, output_path)
    result = convert(input_path)
    AtomicAssessmentsImport::Export.create(output_path, result)
    {
      errors: result[:errors],
    }
  end
end
