module Qdrant
  # Résultat de recherche, type stable exposé au consommateur.
  #
  # SEUL endroit qui connaît les types générés (anti-corruption layer) :
  # parse de `Qdrant::Api::ScoredPoint`. Le déballage du `Response(QueryPoints200Response)`
  # (`.value.result.points`) vit côté `Collection#search`.
  #
  # `id` est un rowid applicatif (Int64). La couche OpenAPI modélise l'id de point
  # en `Int32` (`ExtendedPointId`) ; on élargit en `Int64` côté public — sûr tant
  # que les ids restent < 2³¹. Les ids string (UUID) ne sont pas dans le working set.
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
