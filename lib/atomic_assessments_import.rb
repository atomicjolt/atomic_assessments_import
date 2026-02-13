# frozen_string_literal: true

require "active_support/all"
require "mimemagic"
require "tempfile"
require_relative "atomic_assessments_import/version"
require_relative "atomic_assessments_import/csv"
require_relative "atomic_assessments_import/writer"
require_relative "atomic_assessments_import/export"
require_relative "atomic_assessments_import/exam_soft"
require_relative "atomic_assessments_import/exam_soft/chunker"

module AtomicAssessmentsImport
  class Error < StandardError; end

  def self.register_converter(mime_type, source, klass)
    @converters ||= {}
    @converters[[mime_type, source]] = klass
  end

  def self.convert(path, import_from)
    type = MimeMagic.by_path(path)&.type
    converter_class = @converters[[type, import_from]]
    
    raise "Unsupported file type: #{type} from #{import_from == nil ? "Unspecified Source" : import_from}. Make sure the file type conversion is available for the specified source." unless converter_class
    
    converter_class.new(path).convert
  end

  ######################
  # Register converters: format is register_converter(mime_type, source, class)
  ######################
  # CSV converter - csv is the original/default importer so it can be used with either source specified as "csv" or with no source specified
  register_converter("text/csv", "csv", CSV::Converter)
  register_converter("text/csv", nil, CSV::Converter)

  # ExamSoft converters
  ## rtf
  register_converter("application/rtf", "examsoft", ExamSoft::Converter)
  ## docx
  register_converter("application/vnd.openxmlformats-officedocument.wordprocessingml.document", "examsoft", ExamSoft::Converter)
  ## html
  register_converter("text/html", "examsoft", ExamSoft::Converter) 
  register_converter("application/xhtml+xml", "examsoft", ExamSoft::Converter)

  def self.convert_to_aa_format(input_path, output_path, import_from: nil)
    result = convert(input_path, import_from)
    AtomicAssessmentsImport::Export.create(output_path, result)
    {
      errors: result[:errors],
    }
  end
end
