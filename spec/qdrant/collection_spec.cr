require "../spec_helper"

Spectator.describe Qdrant::Collection do
  let(name) { "spec_lifecycle_#{Random::Secure.hex(4)}" }
  subject(collection) { Qdrant::Collection.new(name) }

  before_each { skip("needs a running Qdrant at #{QDRANT_URL}") unless QDRANT_UP }
  after_each { collection.delete if QDRANT_UP }

  it "creates a collection (idempotent) and counts points" do
    collection.ensure(dim: 4)
    collection.ensure(dim: 4) # idempotent : ne lève pas
    expect(collection.count).to eq(0_i64)
  end
end
