require "../spec_helper"

Spectator.describe Qdrant::Hit do
  it "exposes id, score and payload" do
    hit = Qdrant::Hit.new(
      id: 42_i64,
      score: 0.87_f32,
      payload: {"file" => JSON::Any.new("notes.md")},
    )
    expect(hit.id).to eq(42_i64)
    expect(hit.score).to eq(0.87_f32)
    expect(hit.payload["file"].as_s).to eq("notes.md")
  end
end
