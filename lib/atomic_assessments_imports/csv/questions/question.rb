module AtomicAssessmentsImports
  module CSV
    module Questions
      class Question
        def initialize(row)
          @row = row
        end

        def question_reference
          "csv-import-#{id}"
        end

        def get(string)
          @row.find { |key, value| key.downcase == string.downcase }&.last
        end

        def id
          @id ||= get("question id")
        end

        def text
          @text ||= get("question text")
        end

        def general_feedback
          @general_feedback ||= get("general feedback")
        end

        def tags
          @tags ||= begin
            tags = {}
            @row.each do |key, value|
              next if value.nil?

              if key.downcase.start_with?("tag:")
                tag_name = key.gsub(/tag:/i, "").strip
                tags[tag_name] ||= []
                tags[tag_name] << value
              end

            end

            tags
          end
        end
      end
    end
  end
end
