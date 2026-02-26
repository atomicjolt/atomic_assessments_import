# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class Strategy
        attr_reader :header_nodes

        def initialize
          @header_nodes = []
        end

        # Subclasses implement this. Returns an array of chunks,
        # where each chunk is an array of Nokogiri nodes belonging to one question.
        # Returns empty array if this strategy doesn't apply to the document.
        def split(doc)
          raise NotImplementedError
        end
      end
    end
  end
end
