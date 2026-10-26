require "test_helper"

class PayloadFileTest < ActiveSupport::TestCase
  test "dump and load" do
    content = PayloadFile.dump(uid: "1234", files: { "sub/1.txt" => BASE_MTIME_TIMESTAMP })

    assert_equal "\x1F\x8B".b, content.byteslice(0, 2), "gzipped"
    assert_equal({ uid: "1234", files: { "sub/1.txt" => BASE_MTIME_TIMESTAMP } }, PayloadFile.load(content))
  end

  test "file names that aren't valid UTF-8" do
    latin1 = "caf\xE9.txt".dup.force_encoding(Encoding::UTF_8)
    content = PayloadFile.dump(uid: "1234", files: { latin1 => 1, "café.txt" => 2 })

    files = PayloadFile.load(content)[:files]
    assert_equal 1, files[latin1]
    assert_equal 2, files["café.txt"]
  end

  test "reject payloads of synchronist 1.0.0 and older (Marshal)" do
    error = assert_raises(PayloadFile::InvalidError) do
      PayloadFile.load(Marshal.dump({ uid: "1234", files: { "1.txt" => BASE_MTIME_TIMESTAMP } }))
    end
    assert_match "same version", error.message
  end

  test "reject payloads with unexpected content" do
    [
      Zlib.gzip("[]"),
      Zlib.gzip('{"files": {}}'),
      Zlib.gzip('{"uid": 1, "files": {}}'),
      Zlib.gzip('{"uid": "1234", "files": []}'),
      Zlib.gzip('{"uid": "1234", "files": {"1.txt": "yesterday"}}'),
      Zlib.gzip("not json"),
      '{"uid": "1234", "files": {}}', # not gzipped
      "\x1F\x8B truncated".b,
    ].each do |content|
      assert_raises(PayloadFile::InvalidError, content.inspect) { PayloadFile.load(content) }
    end
  end

  test "reject payloads that are too big uncompressed (gzip bomb)" do
    content = Zlib.gzip(JSON.generate({ uid: "1234", files: {}, padding: " " * 10.megabytes }))
    assert_operator content.bytesize, :<, 100.kilobytes

    error = assert_raises(PayloadFile::InvalidError) { PayloadFile.load(content, max_size: 5.megabytes) }
    assert_match "bigger than 5 MB", error.message
  end

  test "don't record an invalid payload" do
    File.write(Config.payload_path, Marshal.dump({ uid: "1234", files: {} }))

    assert_no_difference -> { Sender::Payload.count + Sync.count } do
      assert_raises(PayloadFile::InvalidError) { Sender::CheckPayloadPathJob.perform_now }
    end
  end

  test "don't send files with names that aren't valid UTF-8 again" do
    name = "caf\xE9.txt".b
    source = Rails.root.join("tmp/payload_file_test")
    FileUtils.rm_rf(source)
    FileUtils.mkdir_p(source)
    begin
      File.binwrite(File.join(source.to_s.b, name), "latin1")
    rescue Errno::EILSEQ
      skip "The file system doesn't allow file names that aren't valid UTF-8 (e.g. APFS on macOS)"
    end

    files = PayloadFile.load(Receiver::Payload.generate("1234", path: source))[:files]
    assert_equal [], Sender::Diff.diff(source, files)
  ensure
    FileUtils.rm_rf(source)
  end
end
