require "test_helper"

class RoundTripTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    FileUtils.touch(Config.source_folder.join("round_trip/file.txt"), mtime: Time.now)
    FileUtils.touch(FIXTURE_DATA.join("receiver/round_trip_storage/file.txt"), mtime: 1.day.ago.utc)

    set_config("STORAGE_FOLDER", FIXTURE_DATA.join("receiver/round_trip_storage"))
    set_config("SOURCE_FOLDER", Config.source_folder.join("round_trip"))
  end

  test "full round trip" do
    # Receiver: Generate payload and send it to sender
    Receiver::Payload.send!

    # The systems in between the sender and receiver are faked by using the same payload path

    # Fake cronjob that checks the payload file for changes
    assert_enqueued_with(job: Sender::ProcessPayloadJob) do
      Sender::CheckPayloadPathJob.perform_now
    end

    # Fake queue workers
    perform_enqueued_jobs

    assert_file_list(["file.txt", "sub/2/2.txt"], Config.send_folder)
    assert_includes File.read(Config.send_folder.join("file.txt")), "this is updated"
  end
end
