# The payload the receiver sends to the sender: The files (with their mtimes) the receiver already has.
#
# It's stored as JSON. The sender reads payloads from a folder other systems write to, so a payload
# must only be able to contain data (Marshal, used before, could run code from a crafted file).
module PayloadFile
  class InvalidError < StandardError; end

  def self.dump(uid:, files:)
    JSON.generate({ uid: uid.to_s, files: files })
  end

  # Returns { uid: String, files: { "path" => mtime (Integer) } }
  def self.load(content)
    data = JSON.parse(content)
    unless data.is_a?(Hash) && data["uid"].is_a?(String) && data["files"].is_a?(Hash) &&
           data["files"].all? { |path, mtime| path.is_a?(String) && mtime.is_a?(Integer) }
      raise InvalidError, "Invalid payload: Expected a uid and files with their mtimes"
    end

    { uid: data["uid"], files: data["files"] }
  rescue JSON::ParserError, EncodingError
    raise InvalidError, "Invalid payload: It's not JSON. Payloads of synchronist 1.0.0 and older can't be read, " \
                        "make sure the receiver and the sender run the same version"
  end
end
