# Flexible ExamSoft Importer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the ExamSoft converter from rigid regex parsing into a flexible chunker + field detector pipeline that handles unknown format variations with best-effort extraction.

**Architecture:** Pandoc normalizes input to HTML, Nokogiri parses to DOM, a strategy-based chunker splits into per-question chunks, independent field detectors extract data from each chunk, and the existing Question pipeline produces Learnosity output. Warnings accumulate rather than halting.

**Tech Stack:** Ruby, RSpec, Nokogiri (already in bundle), PandocRuby (already in bundle), Learnosity format output

---

### Task 1: Chunking Strategy Base Class + MetadataMarkerStrategy

This is the foundation. The MetadataMarkerStrategy replicates the current chunking behavior (split on `Folder:` / `Type:` markers) so we can verify backward compatibility.

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/chunker/strategy.rb`
- Create: `lib/atomic_assessments_import/exam_soft/chunker/metadata_marker_strategy.rb`
- Test: `spec/atomic_assessments_import/examsoft/chunker/metadata_marker_strategy_spec.rb`

**Step 1: Write the failing test**

Create `spec/atomic_assessments_import/examsoft/chunker/metadata_marker_strategy_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::MetadataMarkerStrategy do
  describe "#split" do
    it "splits HTML on Folder: markers" do
      html = <<~HTML
        <p>Folder: Geography Title: Q1 Category: Test 1) What is the capital? ~ Explanation</p>
        <p>*a) Paris</p>
        <p>b) London</p>
        <p>Folder: Science Title: Q2 Category: Test 2) What is H2O? ~ Water</p>
        <p>*a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "splits HTML on Type: markers" do
      html = <<~HTML
        <p>Type: MA Folder: Geography Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
        <p>Type: MCQ Folder: Science Title: Q2 Category: Test 2) Question2? ~ Expl</p>
        <p>*a) Answer2</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no markers found" do
      html = "<p>Just some text with no markers</p>"
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks).to eq([])
    end

    it "separates exam header from questions" do
      html = <<~HTML
        <p>Exam: Midterm 2024</p>
        <p>Total Questions: 30</p>
        <p>Folder: Geography Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(strategy.header_nodes).not_to be_empty
    end

    it "returns chunks as arrays of Nokogiri nodes" do
      html = <<~HTML
        <p>Folder: Geo Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
        <p>b) Wrong</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(chunks[0]).to all(be_a(Nokogiri::XML::Node))
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker/metadata_marker_strategy_spec.rb -v`
Expected: FAIL — uninitialized constant

**Step 3: Write the base Strategy class**

Create `lib/atomic_assessments_import/exam_soft/chunker/strategy.rb`:

```ruby
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
```

**Step 4: Write MetadataMarkerStrategy**

Create `lib/atomic_assessments_import/exam_soft/chunker/metadata_marker_strategy.rb`:

```ruby
# frozen_string_literal: true

require_relative "strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class MetadataMarkerStrategy < Strategy
        MARKER_PATTERN = /\A\s*(?:Type:\s*.+?\s+)?Folder:\s*/i

        def split(doc)
          @header_nodes = []
          chunks = []
          current_chunk = []
          found_first = false

          doc.children.each do |node|
            text = node.text.strip
            next if text.empty? && !node.name.match?(/^(img|table|hr)$/i)

            if text.match?(MARKER_PATTERN)
              found_first = true
              chunks << current_chunk unless current_chunk.empty?
              current_chunk = [node]
            elsif found_first
              current_chunk << node
            else
              @header_nodes << node
            end
          end

          chunks << current_chunk unless current_chunk.empty?
          chunks
        end
      end
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker/metadata_marker_strategy_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/chunker/ spec/atomic_assessments_import/examsoft/chunker/
git commit -m "feat: add chunker base class and MetadataMarkerStrategy"
```

---

### Task 2: NumberedQuestionStrategy

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/chunker/numbered_question_strategy.rb`
- Test: `spec/atomic_assessments_import/examsoft/chunker/numbered_question_strategy_spec.rb`

**Step 1: Write the failing test**

Create `spec/atomic_assessments_import/examsoft/chunker/numbered_question_strategy_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::NumberedQuestionStrategy do
  describe "#split" do
    it "splits on paragraphs starting with number-paren pattern" do
      html = <<~HTML
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>2) What is H2O?</p>
        <p>a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "splits on paragraphs starting with number-dot pattern" do
      html = <<~HTML
        <p>1. What is the capital of France?</p>
        <p>a) Paris</p>
        <p>2. What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no numbered questions found" do
      html = "<p>Just some regular text</p><p>More text</p>"
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks).to eq([])
    end

    it "separates header content before first question" do
      html = <<~HTML
        <p>Exam: Midterm</p>
        <p>Total: 30 questions</p>
        <p>1) First question?</p>
        <p>a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(strategy.header_nodes.length).to eq(2)
    end

    it "does not split on lettered options like a) b) c)" do
      html = <<~HTML
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>c) Berlin</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(1)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker/numbered_question_strategy_spec.rb -v`
Expected: FAIL — uninitialized constant

**Step 3: Write implementation**

Create `lib/atomic_assessments_import/exam_soft/chunker/numbered_question_strategy.rb`:

```ruby
# frozen_string_literal: true

require_relative "strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class NumberedQuestionStrategy < Strategy
        # Matches "1)" or "1." or "12)" etc. at start of text, but NOT single letters like "a)"
        NUMBERED_PATTERN = /\A\s*(\d+)\s*[.)]/

        def split(doc)
          @header_nodes = []
          chunks = []
          current_chunk = []
          found_first = false

          doc.children.each do |node|
            text = node.text.strip
            next if text.empty? && !node.name.match?(/^(img|table|hr)$/i)

            if text.match?(NUMBERED_PATTERN)
              found_first = true
              chunks << current_chunk unless current_chunk.empty?
              current_chunk = [node]
            elsif found_first
              current_chunk << node
            else
              @header_nodes << node
            end
          end

          chunks << current_chunk unless current_chunk.empty?
          # Only valid if we found more than one chunk (single could be a false positive)
          chunks.length > 1 ? chunks : []
        end
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker/numbered_question_strategy_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/chunker/numbered_question_strategy.rb spec/atomic_assessments_import/examsoft/chunker/numbered_question_strategy_spec.rb
git commit -m "feat: add NumberedQuestionStrategy for chunking"
```

---

### Task 3: HeadingSplitStrategy + HorizontalRuleSplitStrategy

These two are simple and follow the same pattern, so they're combined.

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/chunker/heading_split_strategy.rb`
- Create: `lib/atomic_assessments_import/exam_soft/chunker/horizontal_rule_split_strategy.rb`
- Test: `spec/atomic_assessments_import/examsoft/chunker/heading_split_strategy_spec.rb`
- Test: `spec/atomic_assessments_import/examsoft/chunker/horizontal_rule_split_strategy_spec.rb`

**Step 1: Write failing tests**

Create `spec/atomic_assessments_import/examsoft/chunker/heading_split_strategy_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::HeadingSplitStrategy do
  describe "#split" do
    it "splits on heading tags" do
      html = <<~HTML
        <h2>Question 1</h2>
        <p>What is the capital of France?</p>
        <p>a) Paris</p>
        <h2>Question 2</h2>
        <p>What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no headings found" do
      html = "<p>No headings here</p>"
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks).to eq([])
    end

    it "separates header content before first heading" do
      html = <<~HTML
        <p>Exam header info</p>
        <h2>Question 1</h2>
        <p>What is the capital?</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(strategy.header_nodes).not_to be_empty
    end
  end
end
```

Create `spec/atomic_assessments_import/examsoft/chunker/horizontal_rule_split_strategy_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::HorizontalRuleSplitStrategy do
  describe "#split" do
    it "splits on hr tags" do
      html = <<~HTML
        <p>Question 1: What is the capital of France?</p>
        <p>a) Paris</p>
        <hr/>
        <p>Question 2: What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no hr tags found" do
      html = "<p>No rules here</p>"
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks).to eq([])
    end

    it "separates header content before first hr" do
      html = <<~HTML
        <p>Exam header info</p>
        <hr/>
        <p>Question 1</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(strategy.header_nodes).not_to be_empty
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker/heading_split_strategy_spec.rb spec/atomic_assessments_import/examsoft/chunker/horizontal_rule_split_strategy_spec.rb -v`
Expected: FAIL — uninitialized constants

**Step 3: Write implementations**

Create `lib/atomic_assessments_import/exam_soft/chunker/heading_split_strategy.rb`:

```ruby
# frozen_string_literal: true

require_relative "strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class HeadingSplitStrategy < Strategy
        HEADING_PATTERN = /^h[1-6]$/i

        def split(doc)
          @header_nodes = []
          chunks = []
          current_chunk = []
          found_first = false

          doc.children.each do |node|
            if node.name.match?(HEADING_PATTERN)
              found_first = true
              chunks << current_chunk unless current_chunk.empty?
              current_chunk = [node]
            elsif found_first
              text = node.text.strip
              next if text.empty? && !node.name.match?(/^(img|table|hr)$/i)

              current_chunk << node
            else
              @header_nodes << node unless node.text.strip.empty?
            end
          end

          chunks << current_chunk unless current_chunk.empty?
          chunks.length > 1 ? chunks : []
        end
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/exam_soft/chunker/horizontal_rule_split_strategy.rb`:

```ruby
# frozen_string_literal: true

require_relative "strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class HorizontalRuleSplitStrategy < Strategy
        def split(doc)
          @header_nodes = []
          chunks = []
          current_chunk = []
          found_first = false

          doc.children.each do |node|
            if node.name == "hr"
              if current_chunk.empty? && !found_first
                # Content before first hr with no question content is header
                next
              end
              found_first = true
              chunks << current_chunk unless current_chunk.empty?
              current_chunk = []
            elsif found_first || !chunks.empty?
              text = node.text.strip
              next if text.empty? && !node.name.match?(/^(img|table)$/i)

              current_chunk << node
            else
              text = node.text.strip
              if text.empty?
                next
              else
                # Before any hr — could be header or first question
                current_chunk << node
              end
            end
          end

          chunks << current_chunk unless current_chunk.empty?

          if chunks.length > 1
            chunks
          else
            @header_nodes = []
            []
          end
        end
      end
    end
  end
end
```

Note: The HorizontalRuleSplitStrategy is a bit different — the `<hr>` is a separator *between* chunks, not part of a chunk. Content before the first `<hr>` is the first chunk (or header if there's no question content before it).

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker/heading_split_strategy_spec.rb spec/atomic_assessments_import/examsoft/chunker/horizontal_rule_split_strategy_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/chunker/heading_split_strategy.rb lib/atomic_assessments_import/exam_soft/chunker/horizontal_rule_split_strategy.rb spec/atomic_assessments_import/examsoft/chunker/heading_split_strategy_spec.rb spec/atomic_assessments_import/examsoft/chunker/horizontal_rule_split_strategy_spec.rb
git commit -m "feat: add HeadingSplitStrategy and HorizontalRuleSplitStrategy"
```

---

### Task 4: Chunker Orchestrator

The orchestrator tries each strategy and picks the best one.

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/chunker.rb`
- Test: `spec/atomic_assessments_import/examsoft/chunker_spec.rb`

**Step 1: Write the failing test**

Create `spec/atomic_assessments_import/examsoft/chunker_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker do
  describe "#chunk" do
    it "uses MetadataMarkerStrategy when Folder: markers are present" do
      html = <<~HTML
        <p>Folder: Geo Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
        <p>Folder: Sci Title: Q2 Category: Test 2) Question2? ~ Expl</p>
        <p>*a) Answer2</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunker = described_class.new(doc)
      result = chunker.chunk

      expect(result[:chunks].length).to eq(2)
    end

    it "falls back to NumberedQuestionStrategy when no metadata markers" do
      html = <<~HTML
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>2) What is H2O?</p>
        <p>a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunker = described_class.new(doc)
      result = chunker.chunk

      expect(result[:chunks].length).to eq(2)
    end

    it "falls back to HeadingSplitStrategy when no numbers" do
      html = <<~HTML
        <h2>Question 1</h2>
        <p>What is the capital?</p>
        <p>a) Paris</p>
        <h2>Question 2</h2>
        <p>What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunker = described_class.new(doc)
      result = chunker.chunk

      expect(result[:chunks].length).to eq(2)
    end

    it "returns whole document as single chunk when no strategy matches" do
      html = <<~HTML
        <p>Some question text here</p>
        <p>a) An option</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunker = described_class.new(doc)
      result = chunker.chunk

      expect(result[:chunks].length).to eq(1)
      expect(result[:warnings]).to include(/No chunking strategy/i)
    end

    it "extracts header nodes" do
      html = <<~HTML
        <p>Exam: Midterm 2024</p>
        <p>Total Questions: 30</p>
        <p>Folder: Geo Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunker = described_class.new(doc)
      result = chunker.chunk

      expect(result[:header_nodes]).not_to be_empty
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker_spec.rb -v`
Expected: FAIL

**Step 3: Write implementation**

Create `lib/atomic_assessments_import/exam_soft/chunker.rb`:

```ruby
# frozen_string_literal: true

require_relative "chunker/strategy"
require_relative "chunker/metadata_marker_strategy"
require_relative "chunker/numbered_question_strategy"
require_relative "chunker/heading_split_strategy"
require_relative "chunker/horizontal_rule_split_strategy"

module AtomicAssessmentsImport
  module ExamSoft
    class Chunker
      STRATEGIES = [
        Chunker::MetadataMarkerStrategy,
        Chunker::NumberedQuestionStrategy,
        Chunker::HeadingSplitStrategy,
        Chunker::HorizontalRuleSplitStrategy,
      ].freeze

      def initialize(doc)
        @doc = doc
      end

      def chunk
        warnings = []

        STRATEGIES.each do |strategy_class|
          strategy = strategy_class.new
          chunks = strategy.split(@doc)
          next if chunks.empty?

          return {
            chunks: chunks,
            header_nodes: strategy.header_nodes,
            warnings: warnings,
          }
        end

        # No strategy matched — return entire document as one chunk
        all_nodes = @doc.children.reject { |n| n.text.strip.empty? && !n.name.match?(/^(img|table|hr)$/i) }
        warnings << "No chunking strategy matched. Treating entire document as a single question."

        {
          chunks: [all_nodes],
          header_nodes: [],
          warnings: warnings,
        }
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/chunker_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/chunker.rb spec/atomic_assessments_import/examsoft/chunker_spec.rb
git commit -m "feat: add Chunker orchestrator with strategy cascade"
```

---

### Task 5: Field Detectors — QuestionStem, Options, CorrectAnswer

These three are the core detectors needed for MCQ questions.

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/extractor/question_stem_detector.rb`
- Create: `lib/atomic_assessments_import/exam_soft/extractor/options_detector.rb`
- Create: `lib/atomic_assessments_import/exam_soft/extractor/correct_answer_detector.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor/question_stem_detector_spec.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor/options_detector_spec.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor/correct_answer_detector_spec.rb`

**Step 1: Write failing tests**

Create `spec/atomic_assessments_import/examsoft/extractor/question_stem_detector_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::QuestionStemDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts question text before options" do
      nodes = nodes_from(<<~HTML)
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result).to eq("What is the capital of France?")
    end

    it "extracts question text with tilde-separated explanation removed" do
      nodes = nodes_from(<<~HTML)
        <p>Folder: Geo Title: Q1 Category: Test 1) What is the capital? ~ Paris is the capital.</p>
        <p>*a) Paris</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result).to eq("What is the capital?")
    end

    it "extracts question text without numbered prefix" do
      nodes = nodes_from(<<~HTML)
        <p>What is the capital of France?</p>
        <p>a) Paris</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result).to eq("What is the capital of France?")
    end

    it "returns nil when no question text found" do
      nodes = nodes_from("<p>a) Paris</p><p>b) London</p>")
      result = described_class.new(nodes).detect

      expect(result).to be_nil
    end
  end
end
```

Create `spec/atomic_assessments_import/examsoft/extractor/options_detector_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::OptionsDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts lettered options with paren format" do
      nodes = nodes_from(<<~HTML)
        <p>Question text</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>c) Berlin</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result.length).to eq(3)
      expect(result[0][:text]).to eq("Paris")
      expect(result[1][:text]).to eq("London")
      expect(result[2][:text]).to eq("Berlin")
    end

    it "detects correct answer markers with asterisk" do
      nodes = nodes_from(<<~HTML)
        <p>*a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result[0][:correct]).to be true
      expect(result[1][:correct]).to be false
    end

    it "detects correct answer markers with bold" do
      nodes = nodes_from(<<~HTML)
        <p><strong>a) Paris</strong></p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result[0][:correct]).to be true
      expect(result[1][:correct]).to be false
    end

    it "returns empty array when no options found" do
      nodes = nodes_from("<p>Just a paragraph</p>")
      result = described_class.new(nodes).detect

      expect(result).to eq([])
    end

    it "handles uppercase letter options" do
      nodes = nodes_from(<<~HTML)
        <p>A) Paris</p>
        <p>B) London</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result.length).to eq(2)
      expect(result[0][:text]).to eq("Paris")
    end
  end
end
```

Create `spec/atomic_assessments_import/examsoft/extractor/correct_answer_detector_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::CorrectAnswerDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "detects correct answers from asterisk-marked options" do
      options = [
        { text: "Paris", letter: "a", correct: true },
        { text: "London", letter: "b", correct: false },
      ]
      result = described_class.new(nodes_from(""), options).detect

      expect(result).to eq(["a"])
    end

    it "detects multiple correct answers" do
      options = [
        { text: "Little Rock", letter: "a", correct: true },
        { text: "Denver", letter: "b", correct: true },
        { text: "Detroit", letter: "c", correct: false },
      ]
      result = described_class.new(nodes_from(""), options).detect

      expect(result).to eq(["a", "b"])
    end

    it "detects correct answer from Answer: label in chunk" do
      nodes = nodes_from("<p>Answer: A</p>")
      options = [
        { text: "Paris", letter: "a", correct: false },
        { text: "London", letter: "b", correct: false },
      ]
      result = described_class.new(nodes, options).detect

      expect(result).to eq(["a"])
    end

    it "returns empty array when no correct answer found" do
      options = [
        { text: "Paris", letter: "a", correct: false },
        { text: "London", letter: "b", correct: false },
      ]
      result = described_class.new(nodes_from(""), options).detect

      expect(result).to eq([])
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/extractor/ -v`
Expected: FAIL — uninitialized constants

**Step 3: Write implementations**

Create `lib/atomic_assessments_import/exam_soft/extractor/question_stem_detector.rb`:

```ruby
# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class QuestionStemDetector
        OPTION_PATTERN = /\A\s*\*?[a-oA-O][.)]/
        NUMBERED_PREFIX = /\A\s*\d+\s*[.)]\s*/
        METADATA_PREFIX = /\A\s*(?:(?:Type:\s*.+?\s+)?Folder:.+?(?:Title:.+?)?(?:Category:.+?)?)?\s*\d*\s*[.)]?\s*/m
        TILDE_SPLIT = /\s*~\s*/

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          @nodes.each do |node|
            text = node.text.strip
            next if text.empty?
            next if text.match?(OPTION_PATTERN)

            # This node contains the question stem (possibly with metadata prefix)
            # Try to extract just the question part
            stem = extract_stem(text)
            return stem unless stem.nil? || stem.empty?
          end

          nil
        end

        private

        def extract_stem(text)
          # Remove metadata prefix if present (Folder:, Title:, Category:, etc.)
          cleaned = text.sub(METADATA_PREFIX, "")
          # Remove numbered prefix
          cleaned = cleaned.sub(NUMBERED_PREFIX, "")
          # Split on tilde (explanation separator) and take the question part
          cleaned = cleaned.split(TILDE_SPLIT).first
          cleaned&.strip.presence
        end
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/exam_soft/extractor/options_detector.rb`:

```ruby
# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class OptionsDetector
        OPTION_PATTERN = /\A\s*(\*?)([a-oA-O])\s*[.)]\s*(.+)/m

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          options = []

          @nodes.each do |node|
            text = node.text.strip
            match = text.match(OPTION_PATTERN)
            next unless match

            marker = match[1]
            letter = match[2].downcase
            option_text = match[3].strip

            # Check for bold formatting as correct marker
            bold = node.at_css("strong, b")
            is_correct = marker == "*" || (bold && bold.text.strip == text.strip)

            options << {
              text: option_text,
              letter: letter,
              correct: is_correct || false,
            }
          end

          options
        end
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/exam_soft/extractor/correct_answer_detector.rb`:

```ruby
# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class CorrectAnswerDetector
        ANSWER_LABEL_PATTERN = /\bAnswer:\s*([A-Oa-o,;\s]+)/i

        def initialize(nodes, options)
          @nodes = nodes
          @options = options
        end

        def detect
          # First: check options for correct markers (asterisk, bold)
          from_markers = @options.select { |o| o[:correct] }.map { |o| o[:letter] }
          return from_markers unless from_markers.empty?

          # Second: look for "Answer:" label in the chunk
          @nodes.each do |node|
            text = node.text.strip
            match = text.match(ANSWER_LABEL_PATTERN)
            next unless match

            letters = match[1].scan(/[a-oA-O]/).map(&:downcase)
            return letters unless letters.empty?
          end

          []
        end
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/extractor/ -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/extractor/ spec/atomic_assessments_import/examsoft/extractor/
git commit -m "feat: add core field detectors (stem, options, correct answer)"
```

---

### Task 6: Field Detectors — Metadata, Feedback, QuestionType

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/extractor/metadata_detector.rb`
- Create: `lib/atomic_assessments_import/exam_soft/extractor/feedback_detector.rb`
- Create: `lib/atomic_assessments_import/exam_soft/extractor/question_type_detector.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor/metadata_detector_spec.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor/feedback_detector_spec.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor/question_type_detector_spec.rb`

**Step 1: Write failing tests**

Create `spec/atomic_assessments_import/examsoft/extractor/metadata_detector_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::MetadataDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts folder, title, and category" do
      nodes = nodes_from("<p>Folder: Geography Title: Question 1 Category: Subject/Capitals, Difficulty/Normal 1) Question?</p>")
      result = described_class.new(nodes).detect

      expect(result[:folder]).to eq("Geography")
      expect(result[:title]).to eq("Question 1")
      expect(result[:categories]).to include("Subject/Capitals")
    end

    it "extracts type when present" do
      nodes = nodes_from("<p>Type: MA Folder: Geography Title: Q1 Category: Test 1) Question?</p>")
      result = described_class.new(nodes).detect

      expect(result[:type]).to eq("ma")
    end

    it "returns empty hash when no metadata found" do
      nodes = nodes_from("<p>Just a question with no metadata</p>")
      result = described_class.new(nodes).detect

      expect(result).to eq({})
    end
  end
end
```

Create `spec/atomic_assessments_import/examsoft/extractor/feedback_detector_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::FeedbackDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts feedback after tilde" do
      nodes = nodes_from("<p>1) What is the capital? ~ Paris is the capital of France.</p>")
      result = described_class.new(nodes).detect

      expect(result).to eq("Paris is the capital of France.")
    end

    it "extracts feedback from Explanation: label" do
      nodes = nodes_from(<<~HTML)
        <p>What is the capital?</p>
        <p>Explanation: Paris is the capital of France.</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result).to eq("Paris is the capital of France.")
    end

    it "extracts feedback from Rationale: label" do
      nodes = nodes_from(<<~HTML)
        <p>What is the capital?</p>
        <p>Rationale: Paris is the capital of France.</p>
      HTML
      result = described_class.new(nodes).detect

      expect(result).to eq("Paris is the capital of France.")
    end

    it "returns nil when no feedback found" do
      nodes = nodes_from("<p>Just a question</p>")
      result = described_class.new(nodes).detect

      expect(result).to be_nil
    end
  end
end
```

Create `spec/atomic_assessments_import/examsoft/extractor/question_type_detector_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::QuestionTypeDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "detects type from Type: label" do
      nodes = nodes_from("<p>Type: MA Folder: Geo 1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect

      expect(result).to eq("ma")
    end

    it "detects essay from Type: label" do
      nodes = nodes_from("<p>Type: Essay Folder: Geo 1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect

      expect(result).to eq("essay")
    end

    it "defaults to mcq when options are present" do
      nodes = nodes_from("<p>A question with no type label</p>")
      result = described_class.new(nodes, has_options: true).detect

      expect(result).to eq("mcq")
    end

    it "defaults to short_answer when no options" do
      nodes = nodes_from("<p>A question with no type label and no options</p>")
      result = described_class.new(nodes, has_options: false).detect

      expect(result).to eq("short_answer")
    end

    it "detects true/false from Type: label" do
      nodes = nodes_from("<p>Type: True/False 1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect

      expect(result).to eq("true_false")
    end

    it "detects matching from Type: label" do
      nodes = nodes_from("<p>Type: Matching 1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect

      expect(result).to eq("matching")
    end

    it "detects ordering from Type: label" do
      nodes = nodes_from("<p>Type: Ordering 1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect

      expect(result).to eq("ordering")
    end

    it "detects fill_in_the_blank from Type: label" do
      nodes = nodes_from("<p>Type: Fill in the Blank 1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect

      expect(result).to eq("fill_in_the_blank")
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/extractor/ -v`
Expected: FAIL — uninitialized constants for new detectors

**Step 3: Write implementations**

Create `lib/atomic_assessments_import/exam_soft/extractor/metadata_detector.rb`:

```ruby
# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class MetadataDetector
        FOLDER_PATTERN = /Folder:\s*(.+?)(?=\s*(?:Title:|Category:|\d+[.)]))/
        TITLE_PATTERN = /Title:\s*(.+?)(?=\s*(?:Category:|\d+[.)]))/
        CATEGORY_PATTERN = /Category:\s*(.+?)(?=\s*\d+[.)]|\z)/
        TYPE_PATTERN = /Type:\s*(\S+)/

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          # Combine all text from nodes to search for metadata
          full_text = @nodes.map { |n| n.text.strip }.join(" ")
          result = {}

          type_match = full_text.match(TYPE_PATTERN)
          result[:type] = type_match[1].strip.downcase if type_match

          folder_match = full_text.match(FOLDER_PATTERN)
          result[:folder] = folder_match[1].strip if folder_match

          title_match = full_text.match(TITLE_PATTERN)
          result[:title] = title_match[1].strip if title_match

          category_match = full_text.match(CATEGORY_PATTERN)
          if category_match
            result[:categories] = category_match[1].split(",").map(&:strip)
          end

          result
        end
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/exam_soft/extractor/feedback_detector.rb`:

```ruby
# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class FeedbackDetector
        TILDE_PATTERN = /~\s*(.+)/m
        LABEL_PATTERN = /\A\s*(?:Explanation|Rationale):\s*(.+)/im

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          # First: look for tilde-separated feedback in any node
          @nodes.each do |node|
            text = node.text.strip
            match = text.match(TILDE_PATTERN)
            if match
              feedback = match[1].strip
              return feedback unless feedback.empty?
            end
          end

          # Second: look for labeled feedback (Explanation:, Rationale:)
          @nodes.each do |node|
            text = node.text.strip
            match = text.match(LABEL_PATTERN)
            return match[1].strip if match
          end

          nil
        end
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/exam_soft/extractor/question_type_detector.rb`:

```ruby
# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class QuestionTypeDetector
        TYPE_LABEL_PATTERN = /Type:\s*(.+?)(?=\s*(?:Folder:|Title:|Category:|\d+[.)]|\z))/i

        TYPE_MAP = {
          /\Amcq?\z/i => "mcq",
          /\Amultiple\s*choice\z/i => "mcq",
          /\Ama\z/i => "ma",
          /\Amultiple\s*(?:select|answer|response)\z/i => "ma",
          /\Atrue[\s\/]*false\z/i => "true_false",
          /\At\s*\/?\s*f\z/i => "true_false",
          /\Aessay\z/i => "essay",
          /\Along\s*answer\z/i => "essay",
          /\Ashort\s*answer\z/i => "short_answer",
          /\Afill[\s_-]*in[\s_-]*(?:the[\s_-]*)?blank\z/i => "fill_in_the_blank",
          /\Acloze\z/i => "fill_in_the_blank",
          /\Amatching\z/i => "matching",
          /\Aorder(?:ing)?\z/i => "ordering",
        }.freeze

        def initialize(nodes, has_options:)
          @nodes = nodes
          @has_options = has_options
        end

        def detect
          # Try to find an explicit Type: label
          full_text = @nodes.map { |n| n.text.strip }.join(" ")
          match = full_text.match(TYPE_LABEL_PATTERN)

          if match
            type_text = match[1].strip
            TYPE_MAP.each do |pattern, type|
              return type if type_text.match?(pattern)
            end
            # Unknown explicit type — return it lowercased as-is
            return type_text.downcase.gsub(/\s+/, "_")
          end

          # No explicit type — infer from structure
          @has_options ? "mcq" : "short_answer"
        end
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/extractor/ -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/extractor/ spec/atomic_assessments_import/examsoft/extractor/
git commit -m "feat: add metadata, feedback, and question type detectors"
```

---

### Task 7: Extractor Orchestrator

Assembles all detectors and builds the `row_mock` hash.

**Files:**
- Create: `lib/atomic_assessments_import/exam_soft/extractor.rb`
- Test: `spec/atomic_assessments_import/examsoft/extractor_spec.rb`

**Step 1: Write the failing test**

Create `spec/atomic_assessments_import/examsoft/extractor_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#extract" do
    it "extracts a complete MCQ question" do
      nodes = nodes_from(<<~HTML)
        <p>Folder: Geography Title: Question 1 Category: Subject/Capitals 1) What is the capital of France? ~ Paris is the capital.</p>
        <p>*a) Paris</p>
        <p>b) London</p>
        <p>c) Berlin</p>
      HTML
      result = described_class.new(nodes).extract

      expect(result[:row]["question text"]).to eq("What is the capital of France?")
      expect(result[:row]["option a"]).to eq("Paris")
      expect(result[:row]["option b"]).to eq("London")
      expect(result[:row]["option c"]).to eq("Berlin")
      expect(result[:row]["correct answer"]).to eq("a")
      expect(result[:row]["title"]).to eq("Question 1")
      expect(result[:row]["folder"]).to eq("Geography")
      expect(result[:row]["general feedback"]).to eq("Paris is the capital.")
      expect(result[:row]["question type"]).to eq("mcq")
      expect(result[:status]).to eq("published")
      expect(result[:warnings]).to be_empty
    end

    it "returns draft status when no correct answer" do
      nodes = nodes_from(<<~HTML)
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).extract

      expect(result[:status]).to eq("draft")
      expect(result[:warnings]).to include(/correct answer/i)
    end

    it "returns draft status when no question text found" do
      nodes = nodes_from(<<~HTML)
        <p>a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).extract

      expect(result[:status]).to eq("draft")
      expect(result[:warnings]).to include(/question text/i)
    end

    it "handles multiple correct answers for MA type" do
      nodes = nodes_from(<<~HTML)
        <p>Type: MA Folder: Geo Title: Q1 Category: Test 1) Pick capitals? ~ Explanation</p>
        <p>*a) Paris</p>
        <p>*b) Berlin</p>
        <p>c) Detroit</p>
      HTML
      result = described_class.new(nodes).extract

      expect(result[:row]["correct answer"]).to eq("a; b")
      expect(result[:row]["question type"]).to eq("ma")
    end

    it "extracts essay questions without options" do
      nodes = nodes_from(<<~HTML)
        <p>Type: Essay Folder: Writing Title: Q1 Category: Test 1) Discuss the causes of WWI.</p>
      HTML
      result = described_class.new(nodes).extract

      expect(result[:row]["question type"]).to eq("essay")
      expect(result[:row]["question text"]).to eq("Discuss the causes of WWI.")
      expect(result[:status]).to eq("published")
    end

    it "warns for unsupported question types but still imports" do
      nodes = nodes_from(<<~HTML)
        <p>Type: Hotspot 1) Identify the region on the map.</p>
      HTML
      result = described_class.new(nodes).extract

      expect(result[:status]).to eq("draft")
      expect(result[:warnings]).to include(/unsupported.*hotspot/i)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/extractor_spec.rb -v`
Expected: FAIL

**Step 3: Write implementation**

Create `lib/atomic_assessments_import/exam_soft/extractor.rb`:

```ruby
# frozen_string_literal: true

require_relative "extractor/question_stem_detector"
require_relative "extractor/options_detector"
require_relative "extractor/correct_answer_detector"
require_relative "extractor/metadata_detector"
require_relative "extractor/feedback_detector"
require_relative "extractor/question_type_detector"

module AtomicAssessmentsImport
  module ExamSoft
    class Extractor
      SUPPORTED_TYPES = %w[mcq ma true_false essay short_answer fill_in_the_blank matching ordering].freeze
      # Types that require options and a correct answer
      OPTION_TYPES = %w[mcq ma true_false].freeze

      def initialize(nodes)
        @nodes = nodes
      end

      def extract
        warnings = []

        # Run detectors
        options = Extractor::OptionsDetector.new(@nodes).detect
        has_options = !options.empty?

        metadata = Extractor::MetadataDetector.new(@nodes).detect
        question_type = Extractor::QuestionTypeDetector.new(@nodes, has_options: has_options).detect
        stem = Extractor::QuestionStemDetector.new(@nodes).detect
        feedback = Extractor::FeedbackDetector.new(@nodes).detect
        correct_answers = has_options ? Extractor::CorrectAnswerDetector.new(@nodes, options).detect : []

        # Determine status
        status = "published"

        unless SUPPORTED_TYPES.include?(question_type)
          warnings << "Unsupported question type '#{question_type}', imported as draft"
          status = "draft"
        end

        if stem.nil?
          warnings << "No question text found, imported as draft"
          status = "draft"
        end

        if OPTION_TYPES.include?(question_type)
          if options.empty?
            warnings << "No options found for #{question_type} question, imported as draft"
            status = "draft"
          end
          if correct_answers.empty?
            warnings << "No correct answer found, imported as draft"
            status = "draft"
          end
        end

        # Build row_mock
        row = {
          "question id" => nil,
          "folder" => metadata[:folder],
          "title" => metadata[:title],
          "category" => metadata[:categories] || [],
          "import type" => nil,
          "description" => nil,
          "question text" => stem,
          "question type" => question_type,
          "stimulus review" => nil,
          "instructor stimulus" => nil,
          "correct answer" => correct_answers.join("; "),
          "scoring type" => nil,
          "points" => nil,
          "distractor rationale" => nil,
          "sample answer" => nil,
          "acknowledgements" => nil,
          "general feedback" => feedback,
          "correct feedback" => nil,
          "incorrect feedback" => nil,
          "shuffle options" => nil,
          "template" => question_type,
        }

        # Add option keys
        options.each_with_index do |opt, index|
          letter = ("a".ord + index).chr
          row["option #{letter}"] = opt[:text]
        end

        {
          row: row,
          status: status,
          warnings: warnings,
        }
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/extractor_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/extractor.rb spec/atomic_assessments_import/examsoft/extractor_spec.rb
git commit -m "feat: add Extractor orchestrator with field detection pipeline"
```

---

### Task 8: New Question Type Classes — Essay and ShortAnswer

**Files:**
- Create: `lib/atomic_assessments_import/questions/essay.rb`
- Create: `lib/atomic_assessments_import/questions/short_answer.rb`
- Test: `spec/atomic_assessments_import/questions/essay_spec.rb`
- Test: `spec/atomic_assessments_import/questions/short_answer_spec.rb`
- Modify: `lib/atomic_assessments_import/questions/question.rb:12-18` (add cases to `self.load`)

**Step 1: Write failing tests**

Create `spec/atomic_assessments_import/questions/essay_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Essay do
  let(:row) do
    {
      "question text" => "Discuss the causes of World War I.",
      "question type" => "essay",
      "general feedback" => "A good answer covers alliances, imperialism, and nationalism.",
      "sample answer" => "World War I was caused by...",
      "points" => "10",
    }
  end

  describe "#question_type" do
    it "returns longanswer" do
      question = described_class.new(row)
      expect(question.question_type).to eq("longanswer")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:type]).to eq("longanswer")
      expect(result[:widget_type]).to eq("response")
      expect(result[:data][:stimulus]).to eq("Discuss the causes of World War I.")
    end

    it "includes max_length when word limit specified" do
      row["word_limit"] = "500"
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:max_length]).to eq(500)
    end

    it "sets metadata" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:metadata][:sample_answer]).to eq("World War I was caused by...")
      expect(result[:data][:metadata][:general_feedback]).to eq("A good answer covers alliances, imperialism, and nationalism.")
    end
  end
end
```

Create `spec/atomic_assessments_import/questions/short_answer_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::ShortAnswer do
  let(:row) do
    {
      "question text" => "What is the chemical symbol for water?",
      "question type" => "short_answer",
      "correct answer" => "H2O",
      "points" => "1",
    }
  end

  describe "#question_type" do
    it "returns shorttext" do
      question = described_class.new(row)
      expect(question.question_type).to eq("shorttext")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:type]).to eq("shorttext")
      expect(result[:widget_type]).to eq("response")
      expect(result[:data][:stimulus]).to eq("What is the chemical symbol for water?")
    end

    it "includes validation with correct answer" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:validation][:valid_response][:value]).to eq("H2O")
      expect(result[:data][:validation][:valid_response][:score]).to eq(1)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/atomic_assessments_import/questions/essay_spec.rb spec/atomic_assessments_import/questions/short_answer_spec.rb -v`
Expected: FAIL — uninitialized constants

**Step 3: Write implementations**

Create `lib/atomic_assessments_import/questions/essay.rb`:

```ruby
# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Essay < Question
      def question_type
        "longanswer"
      end

      def question_data
        data = super
        word_limit = @row["word_limit"]&.to_i
        data[:max_length] = word_limit if word_limit && word_limit > 0
        data
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/questions/short_answer.rb`:

```ruby
# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class ShortAnswer < Question
      def question_type
        "shorttext"
      end

      def question_data
        super.merge(
          validation: {
            valid_response: {
              score: points,
              value: @row["correct answer"] || "",
            },
          }
        )
      end
    end
  end
end
```

**Step 4: Update Question.load** in `lib/atomic_assessments_import/questions/question.rb`

Change the `self.load` method to include new types:

```ruby
def self.load(row)
  case row["question type"]
  when nil, "", /multiple choice/i, /mcq/i, /^ma$/i
    MultipleChoice.new(row)
  when /true_false/i, /true\/false/i
    MultipleChoice.new(row)
  when /essay/i, /longanswer/i
    Essay.new(row)
  when /short_answer/i, /shorttext/i
    ShortAnswer.new(row)
  else
    raise "Unknown question type #{row['question type']}"
  end
end
```

Also add requires at the top of `question.rb` — actually, since `question.rb` is loaded first and subclasses require it, just add the requires in the extractor/converter that uses `Question.load`. The existing pattern is that `converter.rb` files require all question classes. We'll add the new requires there.

For now, add to the top of `lib/atomic_assessments_import/questions/question.rb` after the class definition is loaded — actually the simplest approach: add requires in the files that use `Question.load`. The existing exam_soft converter already requires question and multiple_choice. We'll add essay and short_answer requires alongside those.

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/atomic_assessments_import/questions/essay_spec.rb spec/atomic_assessments_import/questions/short_answer_spec.rb -v`
Expected: PASS

**Step 6: Run all tests to check nothing broke**

Run: `bundle exec rspec`
Expected: All pass

**Step 7: Commit**

```bash
git add lib/atomic_assessments_import/questions/essay.rb lib/atomic_assessments_import/questions/short_answer.rb lib/atomic_assessments_import/questions/question.rb spec/atomic_assessments_import/questions/essay_spec.rb spec/atomic_assessments_import/questions/short_answer_spec.rb
git commit -m "feat: add Essay and ShortAnswer question types"
```

---

### Task 9: New Question Type Classes — FillInTheBlank, Matching, Ordering

**Files:**
- Create: `lib/atomic_assessments_import/questions/fill_in_the_blank.rb`
- Create: `lib/atomic_assessments_import/questions/matching.rb`
- Create: `lib/atomic_assessments_import/questions/ordering.rb`
- Test: `spec/atomic_assessments_import/questions/fill_in_the_blank_spec.rb`
- Test: `spec/atomic_assessments_import/questions/matching_spec.rb`
- Test: `spec/atomic_assessments_import/questions/ordering_spec.rb`
- Modify: `lib/atomic_assessments_import/questions/question.rb:12-18` (add remaining cases to `self.load`)

**Step 1: Write failing tests**

Create `spec/atomic_assessments_import/questions/fill_in_the_blank_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::FillInTheBlank do
  let(:row) do
    {
      "question text" => "The capital of France is {{response}}.",
      "question type" => "fill_in_the_blank",
      "correct answer" => "Paris",
      "points" => "1",
    }
  end

  describe "#question_type" do
    it "returns clozetext" do
      question = described_class.new(row)
      expect(question.question_type).to eq("clozetext")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:type]).to eq("clozetext")
      expect(result[:data][:stimulus]).to eq("The capital of France is {{response}}.")
    end

    it "includes validation with correct answer" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:validation][:valid_response][:score]).to eq(1)
      expect(result[:data][:validation][:valid_response][:value]).to eq(["Paris"])
    end
  end
end
```

Create `spec/atomic_assessments_import/questions/matching_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Matching do
  let(:row) do
    {
      "question text" => "Match the countries to their capitals.",
      "question type" => "matching",
      "option a" => "France",
      "option b" => "Germany",
      "option c" => "Spain",
      "match a" => "Paris",
      "match b" => "Berlin",
      "match c" => "Madrid",
      "points" => "3",
    }
  end

  describe "#question_type" do
    it "returns association" do
      question = described_class.new(row)
      expect(question.question_type).to eq("association")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:type]).to eq("association")
      expect(result[:data][:stimulus]).to eq("Match the countries to their capitals.")
    end

    it "includes stimulus and possible responses" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:stimulus_list].length).to eq(3)
      expect(result[:data][:possible_responses].length).to eq(3)
    end

    it "includes validation" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:validation][:valid_response][:score]).to eq(3)
      expect(result[:data][:validation][:valid_response][:value].length).to eq(3)
    end
  end
end
```

Create `spec/atomic_assessments_import/questions/ordering_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Ordering do
  let(:row) do
    {
      "question text" => "Arrange these events in chronological order.",
      "question type" => "ordering",
      "option a" => "World War I",
      "option b" => "World War II",
      "option c" => "Cold War",
      "correct answer" => "a; b; c",
      "points" => "3",
    }
  end

  describe "#question_type" do
    it "returns orderlist" do
      question = described_class.new(row)
      expect(question.question_type).to eq("orderlist")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:type]).to eq("orderlist")
      expect(result[:data][:stimulus]).to eq("Arrange these events in chronological order.")
    end

    it "includes list of items" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:list].length).to eq(3)
    end

    it "includes validation with correct order" do
      question = described_class.new(row)
      result = question.to_learnosity

      expect(result[:data][:validation][:valid_response][:score]).to eq(3)
      expect(result[:data][:validation][:valid_response][:value]).to eq(["0", "1", "2"])
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/atomic_assessments_import/questions/fill_in_the_blank_spec.rb spec/atomic_assessments_import/questions/matching_spec.rb spec/atomic_assessments_import/questions/ordering_spec.rb -v`
Expected: FAIL — uninitialized constants

**Step 3: Write implementations**

Create `lib/atomic_assessments_import/questions/fill_in_the_blank.rb`:

```ruby
# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class FillInTheBlank < Question
      def question_type
        "clozetext"
      end

      def question_data
        answers = (@row["correct answer"] || "").split(";").map(&:strip)

        super.merge(
          validation: {
            valid_response: {
              score: points,
              value: answers,
            },
          }
        )
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/questions/matching.rb`:

```ruby
# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Matching < Question
      INDEXES = ("a".."o").to_a.freeze

      def question_type
        "association"
      end

      def question_data
        stimulus_list = []
        possible_responses = []
        valid_values = []

        INDEXES.each do |letter|
          option = @row["option #{letter}"]
          match = @row["match #{letter}"]
          break unless option

          stimulus_list << option
          possible_responses << match if match
          valid_values << match if match
        end

        super.merge(
          stimulus_list: stimulus_list,
          possible_responses: possible_responses,
          validation: {
            valid_response: {
              score: points,
              value: valid_values,
            },
          }
        )
      end
    end
  end
end
```

Create `lib/atomic_assessments_import/questions/ordering.rb`:

```ruby
# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Ordering < Question
      INDEXES = ("a".."o").to_a.freeze

      def question_type
        "orderlist"
      end

      def question_data
        items = []
        INDEXES.each do |letter|
          option = @row["option #{letter}"]
          break unless option

          items << option
        end

        # Parse correct order from "a; b; c" format
        order = (@row["correct answer"] || "").split(";").map(&:strip).map(&:downcase)
        valid_values = order.filter_map { |letter| INDEXES.find_index(letter)&.to_s }

        super.merge(
          list: items,
          validation: {
            valid_response: {
              score: points,
              value: valid_values,
            },
          }
        )
      end
    end
  end
end
```

**Step 4: Update Question.load** in `lib/atomic_assessments_import/questions/question.rb`

Final version of `self.load`:

```ruby
def self.load(row)
  case row["question type"]
  when nil, "", /multiple choice/i, /mcq/i, /^ma$/i
    MultipleChoice.new(row)
  when /true_false/i, /true\/false/i
    MultipleChoice.new(row)
  when /essay/i, /longanswer/i
    Essay.new(row)
  when /short_answer/i, /shorttext/i
    ShortAnswer.new(row)
  when /fill_in_the_blank/i, /cloze/i
    FillInTheBlank.new(row)
  when /matching/i, /association/i
    Matching.new(row)
  when /ordering/i, /orderlist/i
    Ordering.new(row)
  else
    raise "Unknown question type #{row['question type']}"
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/atomic_assessments_import/questions/ -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/atomic_assessments_import/questions/ spec/atomic_assessments_import/questions/
git commit -m "feat: add FillInTheBlank, Matching, and Ordering question types"
```

---

### Task 10: Refactor ExamSoft::Converter to Use New Pipeline

Replace the monolithic regex-based converter with the chunker + extractor pipeline.

**Files:**
- Modify: `lib/atomic_assessments_import/exam_soft/converter.rb` (major rewrite)
- Modify: `lib/atomic_assessments_import/exam_soft.rb` (add requires)

**Step 1: Read and understand the existing converter**

The existing converter is at `lib/atomic_assessments_import/exam_soft/converter.rb`. It handles:
1. File input (String path or Tempfile)
2. Pandoc conversion to HTML
3. Regex chunking + extraction
4. Building row_mock
5. Calling convert_row to build items/questions

We keep steps 1-2 and 5, replace step 3-4 with Chunker + Extractor.

**Step 2: Rewrite the converter**

Replace `lib/atomic_assessments_import/exam_soft/converter.rb` with:

```ruby
# frozen_string_literal: true

require "pandoc-ruby"
require "nokogiri"
require "active_support/core_ext/digest/uuid"

require_relative "../questions/question"
require_relative "../questions/multiple_choice"
require_relative "../questions/essay"
require_relative "../questions/short_answer"
require_relative "../questions/fill_in_the_blank"
require_relative "../questions/matching"
require_relative "../questions/ordering"
require_relative "../utils"
require_relative "chunker"
require_relative "extractor"

module AtomicAssessmentsImport
  module ExamSoft
    class Converter
      def initialize(file)
        @file = file
      end

      def convert
        html = normalize_to_html
        doc = Nokogiri::HTML.fragment(html)

        # Chunk the document
        chunk_result = Chunker.new(doc).chunk
        all_warnings = chunk_result[:warnings].dup

        # Log header info if present
        unless chunk_result[:header_nodes].empty?
          header_text = chunk_result[:header_nodes].map { |n| n.text.strip }.join(" ")
          all_warnings << "Exam header detected: #{header_text}" unless header_text.empty?
        end

        items = []
        questions = []

        chunk_result[:chunks].each_with_index do |chunk_nodes, index|
          # Extract fields from this chunk
          extraction = Extractor.new(chunk_nodes).extract
          all_warnings.concat(extraction[:warnings].map { |w| "Question #{index + 1}: #{w}" })

          row = extraction[:row]
          status = extraction[:status]

          # Skip completely unparseable chunks
          if row["question text"].nil? && row["option a"].nil?
            all_warnings << "Question #{index + 1}: Skipped — no usable content found"
            next
          end

          begin
            item, question_widgets = convert_row(row, status)
            items << item
            questions += question_widgets
          rescue StandardError => e
            title = row["title"] || "Question #{index + 1}"
            all_warnings << "#{title}: #{e.message}, imported as draft"
            # Attempt bare-minimum import
            begin
              item, question_widgets = convert_row_minimal(row)
              items << item
              questions += question_widgets
            rescue StandardError
              all_warnings << "#{title}: Could not import even minimally, skipped"
            end
          end
        end

        {
          activities: [],
          items: items,
          questions: questions,
          features: [],
          errors: all_warnings,
        }
      end

      private

      def normalize_to_html
        if @file.is_a?(String)
          PandocRuby.new([@file], from: @file.split(".").last).to_html
        else
          source_type = @file.path.split(".").last.match(/^[a-zA-Z]+/)[0]
          PandocRuby.new(@file.read, from: source_type).to_html
        end
      end

      def categories_to_tags(categories)
        tags = {}
        (categories || []).each do |cat|
          if cat.include?("/")
            key, value = cat.split("/", 2).map(&:strip)
            tags[key.to_sym] ||= []
            tags[key.to_sym] << value
          else
            tags[cat.to_sym] ||= []
          end
        end
        tags
      end

      def convert_row(row, status = "published")
        source = "<p>ExamSoft Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n"
        if row["question id"].present?
          source += "<p>External id: #{row['question id']}</p>\n"
        end

        question = Questions::Question.load(row)
        item = {
          reference: SecureRandom.uuid,
          title: row["title"] || "",
          status: status,
          tags: categories_to_tags(row["category"]),
          metadata: {
            import_date: Time.now.iso8601,
            import_type: row["import_type"] || "examsoft",
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
            ],
          },
        }
        [item, [question.to_learnosity]]
      end

      def convert_row_minimal(row)
        # Fallback: create a bare item with just the question text
        reference = SecureRandom.uuid
        item = {
          reference: reference,
          title: row["title"] || "",
          status: "draft",
          tags: {},
          metadata: {
            import_date: Time.now.iso8601,
            import_type: "examsoft",
          },
          source: "<p>ExamSoft Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n",
          description: row["question text"] || "",
          questions: [],
          features: [],
          definition: { widgets: [] },
        }
        [item, []]
      end
    end
  end
end
```

**Step 3: Run existing tests to check backward compatibility**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/ -v`
Expected: Existing tests should mostly pass. Some may need minor adjustments due to error handling changes (e.g., "raises if no options" now produces a warning instead of an exception).

**Step 4: Update existing ExamSoft specs for new behavior**

The tests that expect `raise_error` for missing options/correct answers need to change — the new converter uses best-effort and produces warnings instead. Update `spec/atomic_assessments_import/examsoft/docx_converter_spec.rb`:

Change the "raises if no options" test to:
```ruby
it "warns and imports as draft if no options are given" do
  no_options = Tempfile.new("temp.docx")
  original_content = File.read("spec/fixtures/no_options.docx")
  no_options.write(original_content)
  no_options.rewind

  data = described_class.new(no_options).convert
  expect(data[:errors]).to include(a_string_matching(/no options|missing options/i))
end
```

Change the "raises if no correct answer" test to:
```ruby
it "warns and imports as draft if no correct answer is given" do
  no_correct = Tempfile.new("temp.docx")
  original_content = File.read("spec/fixtures/no_correct.docx")
  no_correct.write(original_content)
  no_correct.rewind

  data = described_class.new(no_correct).convert
  expect(data[:errors]).to include(a_string_matching(/correct answer/i))
end
```

Apply similar changes to `html_converter_spec.rb` and `rtf_converter_spec.rb`.

**Step 5: Run all tests**

Run: `bundle exec rspec`
Expected: All pass

**Step 6: Commit**

```bash
git add lib/atomic_assessments_import/exam_soft/ spec/atomic_assessments_import/examsoft/
git commit -m "refactor: rewrite ExamSoft converter to use chunker + extractor pipeline"
```

---

### Task 11: Integration Tests — Mixed Types, Messy Documents, Partial Parse

**Files:**
- Create: `spec/fixtures/mixed_types.html`
- Create: `spec/fixtures/messy_document.html`
- Create: `spec/atomic_assessments_import/examsoft/integration_spec.rb`

**Step 1: Create test fixtures**

Create `spec/fixtures/mixed_types.html`:

```html
<p>Exam: Midterm 2024</p>
<p>Total Questions: 4</p>
<p>Folder: Science Title: Q1 Category: Biology/Cells 1) What is the powerhouse of the cell? ~ The mitochondria produces ATP.</p>
<p>*a) Mitochondria</p>
<p>b) Nucleus</p>
<p>c) Ribosome</p>
<p>Type: Essay Folder: Writing Title: Q2 Category: English/Composition 2) Discuss the themes of Hamlet.</p>
<p>Type: MA Folder: Geography Title: Q3 Category: Capitals 3) Select all European capitals.</p>
<p>*a) Paris</p>
<p>*b) Berlin</p>
<p>c) New York</p>
<p>Folder: Science Title: Q4 Category: Chemistry 4) What is the chemical symbol for gold?</p>
<p>*a) Au</p>
<p>b) Ag</p>
<p>c) Fe</p>
```

Create `spec/fixtures/messy_document.html`:

```html
<p>Some random header text</p>
<p></p>
<p>Folder: Test Title: Q1 Category: General 1) A normal question? ~ Normal explanation</p>
<p>*a) Correct</p>
<p>b) Wrong</p>
<p>Folder: Test Title: Q2 Category: General 2) A question with no options at all</p>
<p>Folder: Test Title: Q3 Category: General 3) Another normal question? ~ Another explanation</p>
<p>*a) Right</p>
<p>b) Wrong</p>
```

**Step 2: Write integration tests**

Create `spec/atomic_assessments_import/examsoft/integration_spec.rb`:

```ruby
# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe "ExamSoft Integration" do
  describe "mixed question types" do
    it "handles a document with MCQ, essay, and MA questions" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/mixed_types.html").convert

      expect(data[:items].length).to eq(4)

      # MCQ question
      q1 = data[:questions].find { |q| q[:data][:stimulus]&.include?("powerhouse") }
      expect(q1).not_to be_nil
      expect(q1[:type]).to eq("mcq")

      # Essay question
      q2 = data[:questions].find { |q| q[:data][:stimulus]&.include?("Hamlet") }
      expect(q2).not_to be_nil
      expect(q2[:type]).to eq("longanswer")

      # MA question
      q3 = data[:questions].find { |q| q[:data][:stimulus]&.include?("European capitals") }
      expect(q3).not_to be_nil
    end

    it "reports exam header in warnings" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/mixed_types.html").convert

      expect(data[:errors]).to include(a_string_matching(/header/i))
    end
  end

  describe "messy documents with partial parse" do
    it "imports what it can and warns about problems" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/messy_document.html").convert

      # Should get at least 2 good items (Q1 and Q3)
      published = data[:items].select { |i| i[:status] == "published" }
      expect(published.length).to be >= 2

      # Should have warnings about Q2 (no options for what looks like MCQ)
      expect(data[:errors].length).to be > 0
    end
  end

  describe "backward compatibility" do
    it "produces the same structure from simple.html as before" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/simple.html").convert

      expect(data[:items].length).to eq(3)
      expect(data[:questions].length).to eq(3)
      expect(data[:activities]).to eq([])
      expect(data[:features]).to eq([])

      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:status]).to eq("published")

      q1 = data[:questions].find { |q| q[:data][:stimulus] == "What is the capital of France?" }
      expect(q1).not_to be_nil
      expect(q1[:data][:options].length).to eq(3)
    end
  end
end
```

**Step 3: Run integration tests**

Run: `bundle exec rspec spec/atomic_assessments_import/examsoft/integration_spec.rb -v`
Expected: PASS

**Step 4: Run full test suite**

Run: `bundle exec rspec`
Expected: All pass

**Step 5: Commit**

```bash
git add spec/fixtures/mixed_types.html spec/fixtures/messy_document.html spec/atomic_assessments_import/examsoft/integration_spec.rb
git commit -m "test: add integration tests for mixed types, messy docs, backward compat"
```

---

### Task 12: Final Cleanup and Full Test Run

**Files:**
- Review: all modified files
- Clean up: any dead code from old converter, unused comments

**Step 1: Run full test suite**

Run: `bundle exec rspec --format documentation`
Expected: All pass

**Step 2: Check for dead code**

Look for any leftover references to the old regex patterns in the converter that are no longer needed. The old `chunk_pattern`, `meta_regex`, `question_regex`, `explanation_regex`, `options_regex` constants should all be gone since they were local variables in the old `convert` method.

**Step 3: Run rubocop if configured**

Run: `bundle exec rubocop lib/atomic_assessments_import/exam_soft/ lib/atomic_assessments_import/questions/`
Fix any style issues.

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: cleanup after ExamSoft converter refactor"
```
