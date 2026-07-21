# frozen_string_literal: true

require "spec_helper"
require "atomic_assessments_import/exam_soft/oc_tech/item_builder"

RSpec.describe AtomicAssessmentsImport::ExamSoft::OcTech::ItemBuilder do
  Parsed = AtomicAssessmentsImport::ExamSoft::OcTech::ParsedQuestion

  def build(parsed)
    described_class.build(parsed, exam_title: "NUR 216 Test #2")
  end

  it "builds an MC item titled with the Question ID" do
    result = build(Parsed.new(
                     number: 2, type: :multiple_choice, stem_html: "<p>How many mL?</p>",
                     options: [
                       { letter: "A", label: "12" }, { letter: "B", label: "15" },
                       { letter: "C", label: "20" }, { letter: "D", label: "10" }
                     ],
                     groups: [], metadata: { "question id" => "23271", "point value" => "20", "rationale" => "150/15" },
                     answers: [{ part: nil, text: "D. 10" }], warnings: []
                   ))
    expect(result[:item][:title]).to eq("23271")
    expect(result[:item][:metadata][:import_type]).to eq("examsoft_octech")
    q = result[:questions].first
    expect(q[:data][:type]).to eq("mcq")
    expect(q[:data][:validation][:valid_response][:value]).to eq(["3"])
    expect(q[:data][:validation][:valid_response][:score]).to eq(20.0)
    expect(q[:data][:metadata][:general_feedback]).to eq("150/15")
  end

  it "raises MissingAnswerError for scorable questions without answers" do
    expect do
      build(Parsed.new(
              number: 1, type: :multiple_choice, stem_html: "<p>x</p>",
              options: [{ letter: "A", label: "a" }], groups: [], metadata: {}, answers: [], warnings: []
            ))
    end.to raise_error(described_class::MissingAnswerError)
  end

  it "builds comma-alternate FITB with a warning" do
    result = build(Parsed.new(
                     number: 18, type: :fitb, stem_html: "<p>How many mL? ___</p>",
                     options: [], groups: [], metadata: { "question id" => "36806", "point value" => "3.33" },
                     answers: [{ part: 1, text: "0, none" }], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:type]).to eq("clozetext")
    expect(data[:validation][:valid_response][:value]).to eq(["0"])
    expect(data[:validation][:alt_responses]).to eq([{ score: 3.33, value: ["none"] }])
    expect(result[:warnings].join).to include("alternates")
  end

  it "does not split numeric comma answers" do
    result = build(Parsed.new(
                     number: 1, type: :fitb, stem_html: "<p>x ___</p>", options: [], groups: [],
                     metadata: {}, answers: [{ part: nil, text: "1,000" }], warnings: []
                   ))
    expect(result[:questions].first[:data][:validation][:valid_response][:value]).to eq(["1,000"])
  end

  it "builds one clozetext question for a multi-part FITB" do
    result = build(Parsed.new(
                     number: 3, type: :fitb, stem_html: "<p>How long and when?</p>", options: [], groups: [],
                     metadata: { "point value" => "20" },
                     answers: [{ part: 1, text: "8 hours 20 minutes" }, { part: 2, text: "1420" }], warnings: []
                   ))
    expect(result[:questions].length).to eq(1)
    expect(result[:item][:questions].length).to eq(1)
    data = result[:questions].first[:data]
    expect(data[:type]).to eq("clozetext")
    expect(data[:validation][:valid_response][:value]).to eq(["8 hours 20 minutes", "1420"])
    expect(data[:template].scan("{{response}}").length).to eq(2)
  end

  it "collapses an 11-underscore run into exactly one inline blank" do
    result = build(Parsed.new(
                     number: 1, type: :fitb, stem_html: "<p>Amount? ___________</p>", options: [], groups: [],
                     metadata: {}, answers: [{ part: nil, text: "1.7" }], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:template]).to eq("<p>Amount? {{response}}</p>")
  end

  it "replaces a __1__ numbered marker" do
    result = build(Parsed.new(
                     number: 1, type: :fitb, stem_html: "<p>The __1__ is red.</p>", options: [], groups: [],
                     metadata: {}, answers: [{ part: nil, text: "sky" }], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:template]).to eq("<p>The {{response}} is red.</p>")
  end

  it "appends a blank when the stem has no markers" do
    result = build(Parsed.new(
                     number: 1, type: :fitb, stem_html: "<p>Name it.</p>", options: [], groups: [],
                     metadata: {}, answers: [{ part: nil, text: "answer" }], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:template]).to eq("<p>Name it.</p><p>{{response}}</p>")
  end

  it "warns and appends blanks when marker count doesn't match answer count" do
    result = build(Parsed.new(
                     number: 5, type: :fitb, stem_html: "<p>__1__ and __2__</p>", options: [], groups: [],
                     metadata: {}, answers: [{ part: nil, text: "only one" }], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:template]).to eq("<p>__1__ and __2__</p><p>{{response}}</p>")
    expect(result[:warnings].join).to include("Question 5: blank markers don't match answer count — review layout")
  end

  it "builds bowtie unscored with choose-1 group centered and a warning" do
    result = build(Parsed.new(
                     number: 6, type: :bowtie, stem_html: "<p>Scenario.</p>", options: [],
                     groups: [
                       { title: "Action To Take (choose 2)", choose: 2, options: [{ letter: "A", label: "a1" }] },
                       { title: "Parameter to Monitor (choose 2)", choose: 2, options: [{ letter: "A", label: "p1" }] },
                       { title: "Potential Condition (choose 1)", choose: 1, options: [{ letter: "A", label: "c1" }] },
                     ],
                     metadata: {}, answers: [], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:type]).to eq("bowtie")
    expect(data[:possible_response_groups].map { |g| g[:title] }).to eq(
      ["Action To Take (choose 2)", "Potential Condition (choose 1)", "Parameter to Monitor (choose 2)"]
    )
    expect(result[:warnings].join).to include("without scoring")
  end

  it "builds classification for drag_and_drop with letter answers" do
    result = build(Parsed.new(
                     number: 16, type: :drag_and_drop, stem_html: "<p>Drag the correct answer.</p>",
                     options: [{ letter: "A", label: "one" }, { letter: "B", label: "two" }, { letter: "C", label: "three" }],
                     groups: [], metadata: { "point value" => "4" },
                     answers: [{ part: nil, text: "A. one; C. three" }], warnings: []
                   ))
    data = result[:questions].first[:data]
    expect(data[:type]).to eq("classification")
    expect(data[:validation][:valid_response][:value]).to eq([[0, 2]])
  end
end
