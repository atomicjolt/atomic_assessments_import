# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Ordering < Question
      INDEXES = ("a".."o").to_a.freeze

      def question_type
        "orderlist"
      end

      ORDER_MARKER = /\s*---\s*(\d+)\s*\z/

      def question_data
        raw_items = INDEXES.filter_map { |letter| @row["option #{letter}"] }

        if raw_items.any? { |item| item.match?(ORDER_MARKER) }
          list, valid_values = parse_order_markers(raw_items)
        else
          list = raw_items
          order = (@row["correct answer"] || "").split(";").map(&:strip).map(&:downcase)
          valid_values = order.filter_map { |letter| INDEXES.find_index(letter) }
        end

        super.merge(
          list: list,
          validation: {
            scoring_type: scoring_type,
            valid_response: {
              score: points,
              value: valid_values,
            },
          }
        )
      end

      private

      def parse_order_markers(raw_items)
        items_with_rank = raw_items.map.with_index do |item, idx|
          m = item.match(ORDER_MARKER)
          { text: item.sub(ORDER_MARKER, "").strip, rank: m ? m[1].to_i : idx + 1, original_index: idx }
        end
        list = items_with_rank.map { |i| i[:text] }
        sorted = items_with_rank.sort_by { |i| i[:rank] }
        valid_values = sorted.map { |i| i[:original_index] }
        [list, valid_values]
      end
    end
  end
end
