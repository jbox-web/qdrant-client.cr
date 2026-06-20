require "spectator"
require "http/client"
require "uri"
require "../src/qdrant"

QDRANT_URL = ENV.fetch("QDRANT_URL", "http://localhost:6333")

# Integration specs need a real Qdrant server. Where none is reachable — e.g.
# macOS CI runners, since GitHub `services:` containers are Linux-only — those
# specs self-skip, so the suite still validates compilation + unit logic
# everywhere and the full integration runs on Linux.
QDRANT_UP = begin
  uri = URI.parse(QDRANT_URL)
  client = HTTP::Client.new(uri.host || "localhost", uri.port, tls: uri.scheme == "https")
  client.connect_timeout = 2.seconds
  client.read_timeout = 2.seconds
  success = client.get("/healthz").success?
  client.close
  success
rescue
  false
end
