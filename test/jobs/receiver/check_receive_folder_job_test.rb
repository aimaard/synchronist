require "test_helper"

class Receiver::CheckReceiveFolderJobTest < ActiveJob::TestCase
  test "check receive folder for things to receive" do
    File.write(Config.get!("receiver_receive_folder").join("sample.zip"), "this is a zip")
    File.write(Config.get!("receiver_receive_folder").join("sample.pdf"), "this is a pdf")
    File.write(Config.get!("receiver_receive_folder").join("with space.txt"), "this has a space")

    assert_enqueued_jobs(3, only: Receiver::StoreFileJob) do
      Receiver::CheckReceiveFolderJob.perform_now
    end

    assert_difference -> { ReceivedFile.count }, +3 do
      perform_enqueued_jobs
    end

    assert_equal [], Dir.glob(Config.get!("receiver_receive_folder").join("**/*"))
    assert_includes Dir.chdir(Config.get!("receiver_storage_folder")) { Dir.glob("**/*") }, "sample.zip"
    assert_includes Dir.chdir(Config.get!("receiver_storage_folder")) { Dir.glob("**/*") }, "sample.pdf"
    assert_includes Dir.chdir(Config.get!("receiver_storage_folder")) { Dir.glob("**/*") }, "with space.txt"
  end

  test "relay received files" do
    Config.set!(name: "receiver_relay_mode", value: "1")
    File.write(Config.get!("receiver_receive_folder").join("sample.pdf"), "this is a pdf")
    Receiver::CheckReceiveFolderJob.perform_now
    perform_enqueued_jobs
    assert_includes Dir.chdir(Config.get!("receiver_storage_folder")) { Dir.glob("**/*") }, "sample.pdf"
    assert_includes Dir.chdir(Config.get!("receiver_relay_folder")) { Dir.glob("**/*") }, "sample.pdf"
  end
end
