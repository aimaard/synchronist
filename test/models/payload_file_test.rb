require "test_helper"

class PayloadFileTest < ActiveSupport::TestCase
  test "dump and load" do
    content = PayloadFile.dump(uid: "1234", files: { "sub/1.txt" => BASE_MTIME_TIMESTAMP })

    assert_equal({ uid: "1234", files: { "sub/1.txt" => BASE_MTIME_TIMESTAMP } }, PayloadFile.load(content))
  end

  test "reject payloads of synchronist 1.0.0 and older (Marshal)" do
    error = assert_raises(PayloadFile::InvalidError) do
      PayloadFile.load(Marshal.dump({ uid: "1234", files: { "1.txt" => BASE_MTIME_TIMESTAMP } }))
    end
    assert_match "same version", error.message
  end

  test "reject payloads with unexpected content" do
    [
      "[]",
      '{"files": {}}',
      '{"uid": 1, "files": {}}',
      '{"uid": "1234", "files": []}',
      '{"uid": "1234", "files": {"1.txt": "yesterday"}}',
    ].each do |content|
      assert_raises(PayloadFile::InvalidError, content) { PayloadFile.load(content) }
    end
  end

  test "don't record an invalid payload" do
    File.write(Config.payload_path, Marshal.dump({ uid: "1234", files: {} }))

    assert_no_difference -> { Sender::Payload.count + Sync.count } do
      assert_raises(PayloadFile::InvalidError) { Sender::CheckPayloadPathJob.perform_now }
    end
  end
end
