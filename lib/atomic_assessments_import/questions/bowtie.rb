# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Bowtie < Question
      def question_type
        "bowtie"
      end

      # Imported unscored: OC Tech printouts don't include a machine-readable
      # bowtie answer format yet. Teachers set the valid response in authoring.
      def question_data
        super.merge(
          ui_style: {
            column_titles: @row["response groups"].map { |group| group[:title] },
            show_drag_handle: false,
          },
          group_possible_responses: true,
          possible_response_groups: @row["response groups"],
        )
      end
    end
  end
end
