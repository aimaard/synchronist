require "test_helper"

class Receiver::SendPayloadJobTest < ActiveJob::TestCase
  test "send payload with job" do
    Receiver::SendPayloadJob.perform_now

    assert File.file?(Config.payload_path)
    assert_equal(
      { uid: "testing", files: { "1.txt" => BASE_MTIME_TIMESTAMP } },
      PayloadFile.load(File.read(Config.payload_path))
    )
  end
end
