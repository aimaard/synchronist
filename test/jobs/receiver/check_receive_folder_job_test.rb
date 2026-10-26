require "test_helper"

class Receiver::CheckReceiveFolderJobTest < ActiveJob::TestCase
  test "check receive folder for things to receive" do
    File.write(Config.receive_folder.join("sample.zip"), "this is a zip")
    File.write(Config.receive_folder.join("sample.pdf"), "this is a pdf")
    File.write(Config.receive_folder.join("with space.txt"), "this has a space")

    assert_enqueued_jobs(3, only: Receiver::StoreFileJob) do
      Receiver::CheckReceiveFolderJob.perform_now
    end

    assert_difference -> { ReceivedFile.count }, +3 do
      perform_enqueued_jobs
    end

    assert_equal [], Dir.glob(Config.receive_folder.join("**/*"))
    assert_includes Dir.glob("**/*", base: Config.storage_folder), "sample.zip"
    assert_includes Dir.glob("**/*", base: Config.storage_folder), "sample.pdf"
    assert_includes Dir.glob("**/*", base: Config.storage_folder), "with space.txt"
  end

  test "relay received files" do
    set_config("MODE", "receiver")
    set_config("RELAY_FOLDER", RELAY_FOLDER)
    File.write(Config.receive_folder.join("sample.pdf"), "this is a pdf")
    Receiver::CheckReceiveFolderJob.perform_now
    perform_enqueued_jobs
    assert_includes Dir.glob("**/*", base: Config.storage_folder), "sample.pdf"
    assert_includes Dir.glob("**/*", base: RELAY_FOLDER), "sample.pdf"
  end
end
