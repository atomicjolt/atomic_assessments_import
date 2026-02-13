# Flexible ExamSoft Importer Design

## Problem

The current ExamSoft converter uses rigid regex patterns tied to an assumed export format. Since we don't have real ExamSoft export files and can't confirm the actual format, the importer needs to be flexible enough to handle format variations gracefully.

## Goals

- Handle unknown ExamSoft export formats without breaking
- Support all ExamSoft question types (MCQ, multiple-select, T/F, essay, short answer, fill-in-the-blank, matching, ordering)
- Best-effort import with warnings for unparseable content
- Easy to extend with new chunking strategies and question types

## Pipeline

```
Input File (docx/html/rtf/etc.)
    |
    v
1. Normalize -- Pandoc converts to HTML, Nokogiri parses to DOM
    |
    v
2. Chunk -- Split DOM into one chunk per question
             Tries multiple strategies, picks best
    |
    v
3. Extract -- Per chunk: detect question type,
              extract fields, build row_mock
    |
    v
Existing Question pipeline (Questions::Question.load -> to_learnosity)
```

### Stage 1: Normalize

Unchanged from current approach. Pandoc converts any input format to HTML. Nokogiri (already in bundle) parses the HTML into a DOM. All subsequent processing works on DOM nodes and text content, not raw HTML strings.

### Stage 2: Chunk

The chunker tries multiple splitting strategies in order and picks the first one that produces reasonable results.

**Strategies (in priority order):**

1. Metadata marker split -- split where `Folder:` or `Type:` appears at the start of a paragraph
2. Numbered question split -- split where a paragraph starts with `\d+)` or `\d+.`
3. Heading split -- split on `<h1>`-`<h6>` tags
4. Horizontal rule split -- split on `<hr>` tags

**Scoring:** Each strategy produces candidate chunks. The chunker picks the strategy where the most chunks look "question-like" (contain text followed by lettered/numbered items). Must produce > 1 chunk.

**Exam header:** Content before the first question chunk is treated as a document-level header. Logged for informational purposes (question count, total points, creation date). Can be wired into output later if valuable.

**Extensibility:** Each strategy is a self-contained class with a `split(doc)` method. Adding a new strategy means writing the class and adding it to the list.

If no strategy produces good results, the whole document becomes one chunk and the extractor does its best.

### Stage 3: Extract

The extractor runs independent field detectors against each chunk:

| Detector         | What it looks for                                                       | Required?                          |
|------------------|-------------------------------------------------------------------------|------------------------------------|
| QuestionType     | "Type:" labels, keywords, or inferred from structure                    | No (defaults based on structure)   |
| QuestionStem     | Main question text before options, after numbered prefix                | Yes (warns if missing)             |
| Options          | Lettered/numbered items, bulleted lists                                 | Required for MCQ types             |
| CorrectAnswer    | `*` prefix, bold, "Answer:" label                                       | Required for MCQ types             |
| Metadata         | `Folder:`, `Title:`, `Category:` labels (any order)                     | No                                 |
| Feedback         | Text after `~`, or "Explanation:"/"Rationale:" labels                   | No                                 |
| MatchingPairs    | Two parallel lists or table structure                                   | Required for matching type         |
| OrderingSequence | Numbered/labeled sequence with correct order indicator                  | Required for ordering type         |

Each detector returns its result or nil. The extractor assembles findings into a `row_mock` hash compatible with the existing `Questions::Question.load` pipeline.

## Question Type Mapping

| ExamSoft Type     | Question Class              | Learnosity type | Notes                                      |
|-------------------|-----------------------------|-----------------|---------------------------------------------|
| Multiple Choice   | MultipleChoice (existing)   | mcq             | Single response                             |
| Multiple Select   | MultipleChoice (existing)   | mcq             | `multiple_responses: true`                  |
| True/False        | MultipleChoice (existing)   | mcq             | Two options (True/False)                    |
| Essay             | Essay (new)                 | longanswer      | Optional word limit, sample answer          |
| Short Answer      | ShortAnswer (new)           | shorttext       | Expected answer(s)                          |
| Fill in the Blank | FillInTheBlank (new)        | cloze           | Text with blanks, accepted answers per blank|
| Matching          | Matching (new)              | association     | Two lists of items to pair                  |
| Ordering          | Ordering (new)              | orderlist       | Items with correct sequence                 |

**Future types (out of scope):** Drag and drop, hotspot, numeric/formula, matrix/grid, NGN types (bowtie). When encountered, these are imported best-effort as draft items with a warning.

## Error Handling

**Approach:** Best-effort throughout. Never fail the whole import due to one bad question.

**Warning/error levels:**

- **Info** -- exam header metadata (logged, not surfaced)
- **Warning** -- missing optional fields, unsupported question type imported as draft
- **Error** -- chunk with no usable content, skipped entirely

**Item status based on parse completeness:**

- Fully parsed -> `status: "published"`
- Partially parsed (missing required fields or unsupported type) -> `status: "draft"`
- Completely unparseable -> skipped, error logged

All warnings and errors collected in the output `:errors` array with chunk identifiers.

## Dependencies

- **Nokogiri** -- already in bundle (v1.18.3), used for DOM parsing of Pandoc HTML output
- **Pandoc** -- already used, unchanged
- No new external dependencies

## Testing Strategy

**Fixture-based tests:**
- Existing fixtures (simple.docx, simple.html, simple.rtf) for backward compatibility
- New fixtures for each question type
- "Messy" fixtures: missing fields, mixed types, exam headers, unexpected formatting

**Unit tests:**
- Chunker strategies tested independently
- Field detectors tested independently
- New question type classes tested same as MultipleChoice

**Integration tests:**
- Full pipeline: file in -> items + questions + warnings out
- Partial-parse scenarios: document with N questions where some are unparseable
