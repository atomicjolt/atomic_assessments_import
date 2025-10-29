# frozen_string_literal: true

require "zip"

module AtomicAssessmentsImport
  class Writer
    def initialize(path)
      @path = path
    end

    def open
      @zip = Zip::File.open(@path, create: true)
      yield self
    ensure
      @zip.close
    end

    def write(filename, content)
      raise "Zip file is not open" unless @zip

      @zip.get_output_stream(filename) { |file| file.write(content) }
    end
  end
end
