require "test_helper"

# Jobs run in multiple threads inside one Solid Queue worker process. Dir.chdir with a block is
# process-wide and raises "conflicting chdir during another chdir block" when used concurrently.
class ThreadSafetyTest < ActiveJob::TestCase
  test "file system operations don't change the working directory" do
    File.write(Config.receive_folder.join("sample.zip"), "this is a zip")
    sync = Sync.create!(sender_payload: Sender::Payload.create!(uid: "1234", mtime: Time.now, received_at: Time.now))
    source_path = Config.source_folder.join("simple_add")

    Dir.chdir(Rails.root) do
      Thread.new do
        Receiver::Payload.generate("1234")
        Sender::Diff.diff(source_path, {})
        Sender::Send.send(source_path, ["1.txt"], Config.send_folder, sync)
        Receiver::StoreFileJob.perform_now("sample.zip")
      end.join
    end

    assert_file_list(["1.txt"], Config.send_folder)
    assert File.file?(Config.storage_folder.join("sample.zip"))
  end
end
