require "../spec_helper"

Spectator.describe "Qdrant::Collection#search" do
  let(name) { "spec_search_#{Random::Secure.hex(4)}" }
  subject(collection) { Qdrant::Collection.new(name) }

  before_each do
    skip("needs a running Qdrant at #{QDRANT_URL}") unless QDRANT_UP
    collection.ensure(dim: 4)
    collection.upsert(1_i64, [0.9_f32, 0.1_f32, 0.0_f32, 0.0_f32])
    collection.upsert(2_i64, [0.0_f32, 0.0_f32, 0.1_f32, 0.9_f32])
  end
  after_each { collection.delete if QDRANT_UP }

  it "returns nearest hits as Qdrant::Hit{id, score}, closest first" do
    hits = collection.search([0.9_f32, 0.1_f32, 0.0_f32, 0.0_f32], top_k: 2)
    expect(hits.first).to be_a(Qdrant::Hit)
    expect(hits.first.id).to eq(1_i64)
    expect(hits.first.score).to be > hits.last.score
  end
end
