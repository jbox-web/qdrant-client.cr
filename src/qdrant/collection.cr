require "uri"

module Qdrant
  # Façade stable sur une collection Qdrant — working set RAG (~5 ops).
  #
  # Anti-corruption layer : la construction des requêtes (models générés
  # `CreateCollection`/`VectorParams`/…) est confinée à cette classe ; le
  # déballage des réponses `Response(T)` aussi (`count`, `search`, `exists?`).
  # L'API publique (`Collection`, `Hit`) ne dépend d'aucun type généré.
  class Collection
    getter name : String

    # Cas nominal : Qdrant distant / Cloud → HTTPS + header `api-key` (auth Qdrant,
    # PAS un bearer). Une collection dédiée par corpus isole les ids.
    def initialize(@name : String, url : String = ENV["QDRANT_URL"], api_key : String? = nil)
      uri = URI.parse(url)
      authority = uri.authority || raise ArgumentError.new("Qdrant url has no host: #{url.inspect}")
      @client = Qdrant::Api::Client.new(
        host: authority,
        scheme: uri.scheme || "http",
      )
      # Auth Qdrant = header `api-key`, injecté sur les en-têtes par défaut du
      # transport (Connection#request les recopie avant chaque appel).
      @client.connection.config.default_headers["api-key"] = api_key if api_key
    end

    # PUT /collections/{name} — `collections.update` côté généré. Idempotent :
    # no-op si la collection existe déjà.
    def ensure(dim : Int32, distance : Symbol = :cosine) : Nil
      return if exists?
      params = Qdrant::Api::VectorParams.new(size: dim, distance: distance_name(distance))
      @client.collections.update(
        name,
        Qdrant::Api::CreateCollection.new(vectors: Qdrant::Api::VectorsConfig.new(params)),
      )
    end

    # DELETE /collections/{name} — drop de la collection (= `clear` côté appelant).
    # Tolère l'absence (utilisé en teardown de specs).
    def delete : Nil
      @client.collections.delete(name)
    rescue Qdrant::Api::ApiError
    end

    # PUT /collections/{name}/points — `collections.points.bulk_update` côté généré.
    # Upsert unitaire (payload optionnel, minimal côté RAG : l'hydratation reste à
    # l'appelant).
    def upsert(id : Int64, vector : Array(Float32),
               payload : Hash(String, JSON::Any) = {} of String => JSON::Any) : Nil
      upsert_structs([build_struct(id, vector, payload)])
    end

    # Upsert batch : tableau de tuples `{id, vector}`.
    def upsert(points : Array) : Nil
      upsert_structs(points.map { |point| build_struct(point[0], point[1]) })
    end

    # POST /collections/{name}/points/delete — suppression par ids. L'appelant
    # détient les ids (source de vérité durable), le KNN n'est jamais filtré.
    def delete(ids : Array(Int64)) : Nil
      selector = Qdrant::Api::PointsSelector.new(
        Qdrant::Api::PointIdsList.new(points: ids.map { |i| extended_id(i) }),
      )
      @client.collections.points.delete(name, selector, wait: true)
    end

    # POST /collections/{name}/points/count avec `exact: true` — comptage fiable,
    # utilisé pour la parité et la détection de divergence avec la source durable.
    def count : Int64
      response = @client.collections.points.count(name, Qdrant::Api::CountRequest.new(exact: true))
      response.value.result.try(&.count.to_i64) || 0_i64
    end

    # POST /collections/{name}/points/query — KNN nu (sans filtre). Le déballage
    # `Response → result.points` est confiné ici ; la conversion type-généré →
    # type-maison vit dans `Hit.from`. La fusion éventuelle est à la charge de
    # l'appelant.
    def search(vector : Array(Float32), top_k : Int32 = 20) : Array(Hit)
      request = Qdrant::Api::QueryRequest.new(
        query: Qdrant::Api::QueryInterface.new(Qdrant::Api::VectorInput.new(vector)),
        limit: top_k,
      )
      response = @client.collections.points.query(name, request)
      points = response.value.result.try(&.points) || [] of Qdrant::Api::ScoredPoint
      points.map { |scored| Hit.from(scored) }
    end

    # GET /collections/{name}/exists. Privé : sert l'idempotence d'`ensure`.
    private def exists? : Bool
      @client.collections.exists(name).value.result.try(&.exists) || false
    rescue Qdrant::Api::ApiError
      false
    end

    # Qdrant attend une distance capitalisée : "Cosine"/"Dot"/"Euclid"/"Manhattan".
    private def distance_name(distance : Symbol) : Qdrant::Api::Distance
      distance.to_s.capitalize
    end

    # `wait: true` : l'écriture est confirmée avant retour (le `count` qui suit est
    # alors exact — pas de fenêtre d'indexation asynchrone).
    private def upsert_structs(structs : Array(Qdrant::Api::PointStruct)) : Nil
      @client.collections.points.bulk_update(
        name,
        Qdrant::Api::PointInsertOperations.new(Qdrant::Api::PointsList.new(points: structs)),
        wait: true,
      )
    end

    private def build_struct(id, vector : Array(Float32),
                             payload : Hash(String, JSON::Any) = {} of String => JSON::Any) : Qdrant::Api::PointStruct
      Qdrant::Api::PointStruct.new(
        id: extended_id(id),
        vector: Qdrant::Api::VectorStruct.new(vector),
        payload: payload,
      )
    end

    # L'id de point Qdrant est modélisé en Int32 par la couche OpenAPI.
    private def extended_id(id) : Qdrant::Api::ExtendedPointId
      Qdrant::Api::ExtendedPointId.new(id.to_i32)
    end
  end
end
