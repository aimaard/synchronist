require "test_helper"

class Sender::CheckPayloadPathJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @payload_mtime = (Sender::Payload.ordered.first.mtime + 1.day).utc
    File.write(Config.payload_path, Marshal.dump({ uid: "testing", files: [] }), mode: "wb")
    FileUtils.touch(Config.payload_path, mtime: @payload_mtime)
  end

  test "Check payload path, once updated add models and job to process" do
    assert_enqueued_with(job: Sender::ProcessPayloadJob) do
      assert_difference 'Sender::Payload.count', +1 do
        assert_changes -> { Sender::Payload.ordered.first }, "The created one should be first. Check the fixtures: Make sure everything is in the past" do
          assert_difference 'Sync.count', +1 do
            Sender::CheckPayloadPathJob.perform_now
          end
        end
      end
    end


    assert_no_enqueued_jobs(only: Sender::ProcessPayloadJob) do
      Sender::CheckPayloadPathJob.perform_now
    end


    FileUtils.touch(Config.payload_path, mtime: @payload_mtime + 1.hour)
    assert_enqueued_with(job: Sender::ProcessPayloadJob) do
      Sender::CheckPayloadPathJob.perform_now
    end
  end

  test "Works with the first Sync/Payload to create" do
    SentFile.delete_all
    Sync.delete_all
    Sender::Payload.delete_all

    assert_enqueued_with(job: Sender::ProcessPayloadJob) do
      Sender::CheckPayloadPathJob.perform_now
    end
  end
end
