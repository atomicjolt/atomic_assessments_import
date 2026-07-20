# frozen_string_literal: true

require "nokogiri"

module AtomicAssessmentsImport
  module ExamSoft
    module HtmlNormalizer
      # Split <p> nodes containing <br> into separate <p> nodes so each
      # logical line is its own block element.
      def self.normalize!(doc)
        doc.css("p").each do |p_node|
          br_children = p_node.css("br")
          next if br_children.empty?

          segments = []
          current_segment = []

          p_node.children.each do |child|
            if child.name == "br"
              segments << current_segment unless current_segment.empty?
              current_segment = []
            else
              current_segment << child
            end
          end
          segments << current_segment unless current_segment.empty?

          next if segments.length <= 1

          segments.reverse_each do |segment|
            new_p = Nokogiri::XML::Node.new("p", doc)
            segment.each { |child| new_p.add_child(child.clone) }
            p_node.add_next_sibling(new_p)
          end
          p_node.remove
        end
        doc
      end
    end
  end
end
