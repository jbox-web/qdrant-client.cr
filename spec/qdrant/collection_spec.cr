require "../spec_helper"

Spectator.describe Qdrant::Collection do
  let(name) { "spec_lifecycle_#{Random::Secure.hex(4)}" }
  subject(collection) { Qdrant::Collection.new(name) }

  after_each { collection.delete }

  it "creates a collection (idempotent) and counts points" do
    collection.ensure(dim: 4)
    collection.ensure(dim: 4) # idempotent : ne lève pas
    expect(collection.count).to eq(0_i64)
  end
end
