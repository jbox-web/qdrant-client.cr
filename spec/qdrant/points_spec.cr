require "../spec_helper"

Spectator.describe "Qdrant::Collection points" do
  let(name) { "spec_points_#{Random::Secure.hex(4)}" }
  subject(collection) { Qdrant::Collection.new(name) }

  before_each { collection.ensure(dim: 4) }
  after_each { collection.delete }

  it "upserts (unit + batch) then counts and deletes by ids" do
    collection.upsert(1_i64, [0.1_f32, 0.2_f32, 0.3_f32, 0.4_f32])
    collection.upsert([
      {2_i64, [0.2_f32, 0.1_f32, 0.0_f32, 0.5_f32]},
      {3_i64, [0.0_f32, 0.3_f32, 0.3_f32, 0.1_f32]},
    ])
    expect(collection.count).to eq(3_i64)

    collection.delete([1_i64, 2_i64])
    expect(collection.count).to eq(1_i64)
  end
end
