module Qdrant
  # A search result — the stable type exposed to consumers.
  #
  # The ONLY place that knows the generated types (anti-corruption layer):
  # it parses `Qdrant::Api::ScoredPoint`. Unwrapping the
  # `Response(QueryPoints200Response)` (`.value.result.points`) lives in
  # `Collection#search`.
  #
  # `id` is an application rowid (Int64). The OpenAPI layer models the point id
  # as `Int32` (`ExtendedPointId`); we widen it to `Int64` in the public API —
  # safe as long as ids stay below 2³¹. String ids (UUIDs) aren't in the working
  # set.
  struct Hit
    getter id : Int64
    getter score : Float32
    getter payload : Hash(String, JSON::Any)

    def initialize(@id : Int64, @score : Float32,
                   @payload : Hash(String, JSON::Any) = {} of String => JSON::Any)
    end

    def self.from(scored : Qdrant::Api::ScoredPoint) : Hit
      new(
        id: scored.id.value.as(Int32).to_i64,
        score: scored.score,
        payload: scored.payload || {} of String => JSON::Any,
      )
    end
  end
end
