# frozen_string_literal: true

require "pandoc-ruby"
require "active_support/core_ext/digest/uuid"

require_relative "../questions/question"
require_relative "../questions/multiple_choice"
require_relative "../utils"

module AtomicAssessmentsImport
  module ExamSoft
    class Converter

      def initialize(file)
        @file = file
      end


      def convert
        # Step 1: Parse the ExamSoft file to HTML using Pandoc to formalize the structure
        html = PandocRuby.new([@file], from: @file.split('.').last).to_html

        # Step 2: Extract questions and convert them into AA format

        items = []
        questions = []


        # 1. Chunking Regex (The "Slicer")
        chunk_pattern = /<p>(?:Type:.*?)?Folder:.*?(?=<p>(?:Type:.*?)?Folder:|\z)/m

        # 2. Field Extraction Regexes
        meta_regex = /(?:Type:\s*(?<type>[^<]+?)\s*)?Folder:\s*(?<folder>[^<]+?)\s*Title:\s*(?<title>[^<]+?)\s*Category:\s*(?<category>.+?)\s*(?=\d+\))/m
        question_regex = /\d+\)\s*(?<question>.+?)\s*~/m
        explanation_regex = /~\s*(?<explanation>.+?)(?=<\/p>)/m
        options_regex = /<p>(?<marker>\*?)(?<letter>[a-o])\)\s*(?<text>.+?)<\/p>/

        parsed_questions = []

        # Logic: Chunk the text first
        chunks = html.scan(chunk_pattern)

        chunks.each do |chunk|
          # Clean up internal whitespace for metadata/text matching
          clean_chunk = chunk.gsub(/\n/, " ").gsub(/\s+/, " ")

          meta   = clean_chunk.match(meta_regex)
          q_text = clean_chunk.match(question_regex)
          expl   = clean_chunk.match(explanation_regex)
          
          # Scrape options from the original chunk to preserve HTML structure
          raw_options = chunk.scan(options_regex)
          
          # Identify ALL indices where the marker is '*'
          # We use .map { |i| i + 1 } to convert 0-index to 1-index numbers
          correct_indices = raw_options.each_index.select { |i| raw_options[i][0] == "*" }.map { |i| i + 1 }


          type =        meta && meta[:type] ? meta[:type].strip.downcase : "mcq"
          folder =      meta ? meta[:folder].strip : nil
          title =       meta ? meta[:title].strip : nil
          categories =  meta ? meta[:category].split(",").map(&:strip) : []
          question =    q_text ? q_text[:question].strip : nil
          explanation = expl ? expl[:explanation].strip : nil
          answer_options =     raw_options.map { |opt| opt[2].strip }
          correct_answer_indices = correct_indices 
          

          # Note: a lot of these are nil because ExamSoft RTF doesn't have all the same fields as CSV.
          # They're listed here to show what is being mapped where possible.
          row_mock = {
            "question id" => nil,
            "folder" => folder,
            "title" => title,
            "category" => categories,
            "import type" => nil,
            "description" => nil,
            "question text" => question,
            "question type" => type,
            "stimulus review" => nil,
            "instructor stimulus" => nil,
            "correct answer" => correct_answer_indices.map { |i| ("a".ord + i - 1).chr }.join("; "),
            "scoring type" => nil,
            "points" => nil,
            "distractor rationale" => nil,
            "sample answer" => nil,
            "acknowledgements" => nil,
            "general feedback" => nil,
            "correct feedback" => explanation,
            "incorrect feedback" => nil,
            "shuffle options" => nil,
            "template" => nil,
          }
          
          # Add option keys for the MultipleChoice class
          answer_options.each_with_index do |option_text, index|
            option_letter = ("a".ord + index).chr
            row_mock["option #{option_letter}"] = option_text
          end


        

          item, question_widgets = convert_row(row_mock)

          items << item
          questions += question_widgets
        rescue StandardError => e
          raise e, "Error processing title \"#{title}\": #{e.message}"
        end



          # items << item

          # question_widgets = {
          #   type: question.question_type,
          #   widget_type: "response",
          #   reference: question.reference,
          #   data: {
          #     stimulus: question,
          #     type: question.question_type,
          #     metadata: metadata,
          #     **{ # TODO finish this part
          #       stimulus_review: nil,#@chunk["stimulus review"],
          #       instructor_stimulus: nil#@chunk["instructor stimulus"],
          #     }.compact,
          #   }, #question_data,
          # }
          # questions << question_widgets


        # We should match what we return from the CSV converter
        {
          activities: [],
          items:,
          questions:,
          features: [],
          errors: [],
        }
      end

      private

      def categories_to_tags(categories)
        tags = {}
        categories.each do |cat|
          if cat.include?("/")
            key, value = cat.split("/", 2).map(&:strip) # TODO: deal with multiple slashes? - It could be Tag name/Tag Value/Tag Value2
            tags[key.to_sym] ||= []
            tags[key.to_sym] << value
          else
            tags[cat.to_sym] ||= []
          end
        end
        tags
      end

      def convert_row(row)
        # The csv files had a column for question id, but ExamSoft rtf files does not seem to have that. I'll include Folder instead
        source = "<p>ExamSoft Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n"
        if row["question id"].present?
          source += "<p>External id: #{row['question id']}</p>\n"
        elsif row["folder"].present?
          source += "<p>From Folder: #{row['folder']}</p>\n" # Is folder a good substitute?
        end


        question = Questions::Question.load(row)
        item = {
          reference: SecureRandom.uuid,
          title: row["title"] || "",
          status: "published",
          tags: categories_to_tags(row["category"] || []),
          metadata: {
            import_date: Time.now.iso8601,
            import_type: row["import_type"] || "examsoft",
            **{
              external_id: row["question id"],
              external_id_domain: row["question id"].present? ? "examsoft" : nil, # IDK about this one
              alignment: nil # alignment_urls(row), # No alignment URLs in ExamSoft RTF?
            }.compact,
          },
          source: source,
          description: row["description"] || "",
          questions: [
            {
              reference: question.reference,
              type: question.question_type,
            },
          ],
          features: [],
          definition: {
            widgets: [
              {
                reference: question.reference,
                widget_type: "response",
              },
            ]
          },
        }
        [item, [question.to_learnosity]]
      end


    end
  end
end
