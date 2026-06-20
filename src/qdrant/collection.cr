require "uri"

module Qdrant
  # Stable facade over a Qdrant collection — the RAG working set (~5 ops).
  #
  # Anti-corruption layer: request construction (the generated `CreateCollection`/
  # `VectorParams`/… models) is confined to this class, as is `Response(T)`
  # unwrapping (`count`, `search`, `exists?`). The public API (`Collection`,
  # `Hit`) depends on no generated type.
  class Collection
    getter name : String

    # Happy path: a remote / Cloud Qdrant → HTTPS + `api-key` header (Qdrant's
    # auth, *not* a bearer token). One dedicated collection per corpus keeps ids
    # isolated.
    def initialize(@name : String, url : String = ENV["QDRANT_URL"], api_key : String? = nil)
      uri = URI.parse(url)
      authority = uri.authority || raise ArgumentError.new("Qdrant url has no host: #{url.inspect}")
      @client = Qdrant::Api::Client.new(
        host: authority,
        scheme: uri.scheme || "http",
      )
      # Qdrant auth is the `api-key` header, set on the transport's default
      # headers (Connection#request copies them onto every request).
      @client.connection.config.default_headers["api-key"] = api_key if api_key
    end

    # PUT /collections/{name} — `collections.update` in the generated layer.
    # Idempotent: a no-op when the collection already exists.
    def ensure(dim : Int32, distance : Symbol = :cosine) : Nil
      return if exists?
      params = Qdrant::Api::VectorParams.new(size: dim, distance: distance_name(distance))
      @client.collections.update(
        name,
        Qdrant::Api::CreateCollection.new(vectors: Qdrant::Api::VectorsConfig.new(params)),
      )
    end

    # DELETE /collections/{name} — drops the collection (the caller's `clear`).
    # Tolerates absence (used in spec teardown).
    def delete : Nil
      @client.collections.delete(name)
    rescue Qdrant::Api::ApiError
    end

    # PUT /collections/{name}/points — `collections.points.bulk_update` in the
    # generated layer. Single upsert (payload optional and minimal for RAG:
    # hydration stays with the caller).
    def upsert(id : Int64, vector : Array(Float32),
               payload : Hash(String, JSON::Any) = {} of String => JSON::Any) : Nil
      upsert_structs([build_struct(id, vector, payload)])
    end

    # Batch upsert: an array of `{id, vector}` tuples.
    def upsert(points : Array) : Nil
      upsert_structs(points.map { |point| build_struct(point[0], point[1]) })
    end

    # POST /collections/{name}/points/delete — delete by id. The caller owns the
    # ids (its durable source of truth); KNN is never filtered.
    def delete(ids : Array(Int64)) : Nil
      selector = Qdrant::Api::PointsSelector.new(
        Qdrant::Api::PointIdsList.new(points: ids.map { |i| extended_id(i) }),
      )
      @client.collections.points.delete(name, selector, wait: true)
    end

    # POST /collections/{name}/points/count with `exact: true` — a reliable count,
    # used for parity and to detect divergence from the durable source.
    def count : Int64
      response = @client.collections.points.count(name, Qdrant::Api::CountRequest.new(exact: true))
      response.value.result.try(&.count.to_i64) || 0_i64
    end

    # POST /collections/{name}/points/query — bare KNN (no filter). The
    # `Response → result.points` unwrapping is confined here; the generated →
    # home-grown type conversion lives in `Hit.from`. Any fusion is the caller's
    # job.
    def search(vector : Array(Float32), top_k : Int32 = 20) : Array(Hit)
      request = Qdrant::Api::QueryRequest.new(
        query: Qdrant::Api::QueryInterface.new(Qdrant::Api::VectorInput.new(vector)),
        limit: top_k,
      )
      response = @client.collections.points.query(name, request)
      points = response.value.result.try(&.points) || [] of Qdrant::Api::ScoredPoint
      points.map { |scored| Hit.from(scored) }
    end

    # GET /collections/{name}/exists. Private: backs `ensure`'s idempotence.
    private def exists? : Bool
      @client.collections.exists(name).value.result.try(&.exists) || false
    rescue Qdrant::Api::ApiError
      false
    end

    # Qdrant expects a capitalized distance: "Cosine"/"Dot"/"Euclid"/"Manhattan".
    private def distance_name(distance : Symbol) : Qdrant::Api::Distance
      distance.to_s.capitalize
    end

    # `wait: true`: the write is acknowledged before returning, so a following
    # `count` is exact — no asynchronous indexing window.
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

    # Qdrant point ids are modeled as Int32 by the OpenAPI layer.
    private def extended_id(id) : Qdrant::Api::ExtendedPointId
      Qdrant::Api::ExtendedPointId.new(id.to_i32)
    end
  end
end
