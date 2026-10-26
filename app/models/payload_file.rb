require "zlib"

# The payload the receiver sends to the sender: The files (with their mtimes) the receiver already has.
#
# It's stored as gzipped JSON. The sender reads payloads from a folder other systems write to, so a
# payload must only be able to contain data (Marshal, used before, could run code from a crafted file).
# The list of paths compresses well: The payload of a Debian mirror (1.6 million files) is 15 MB instead of 125 MB.
module PayloadFile
  class InvalidError < StandardError; end

  # Protects the sender from payloads that decompress to huge amounts of data (gzip bombs)
  MAX_SIZE = 4.gigabytes

  # File names that aren't valid UTF-8 can't be stored in JSON as they are. They're stored base64
  # encoded with this prefix instead, a NUL byte can't be part of a file name.
  BINARY_PREFIX = "\0"

  def self.dump(uid:, files:)
    files = files.transform_keys { |path| path.valid_encoding? ? path : BINARY_PREFIX + [path.b].pack("m0") }

    # The payload is only written once per sync and might be sent over a slow connection, so it's worth
    # the extra second for big payloads
    Zlib.gzip(JSON.generate({ uid: uid.to_s, files: files }), level: Zlib::BEST_COMPRESSION)
  end

  # Returns { uid: String, files: { "path" => mtime (Integer) } }
  def self.load(content, max_size: MAX_SIZE)
    data = JSON.parse(inflate(content, max_size))
    unless data.is_a?(Hash) && data["uid"].is_a?(String) && data["files"].is_a?(Hash) &&
           data["files"].all? { |path, mtime| path.is_a?(String) && mtime.is_a?(Integer) }
      raise InvalidError, "Invalid payload: Expected a uid and files with their mtimes"
    end

    files = data["files"].transform_keys do |path|
      next path unless path.start_with?(BINARY_PREFIX)

      path.delete_prefix(BINARY_PREFIX).unpack1("m0").force_encoding(Encoding.find("filesystem"))
    end

    { uid: data["uid"], files: files }
  rescue Zlib::Error, JSON::ParserError, EncodingError, ArgumentError
    raise InvalidError, "Invalid payload: It's not gzipped JSON. Payloads of synchronist 1.0.0 and older can't be " \
                        "read, make sure the receiver and the sender run the same version"
  end

  def self.inflate(content, max_size)
    reader = Zlib::GzipReader.new(StringIO.new(content))
    json = +""
    until reader.eof?
      json << reader.readpartial(1.megabyte)
      raise InvalidError, "Invalid payload: It's bigger than #{max_size.to_fs(:human_size)} uncompressed" if json.bytesize > max_size
    end
    json.force_encoding(Encoding::UTF_8)
  ensure
    reader&.close
  end
  private_class_method :inflate
end
