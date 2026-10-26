require "test_helper"

class Receiver::StoreFileJobTest < ActiveJob::TestCase
  test "move received files into the storage folder" do
    FileUtils.mkdir_p(Config.receive_folder.join("sub"))
    File.write(Config.receive_folder.join("sample.zip"), "this is a zip")
    File.write(Config.receive_folder.join("sub/sample.pdf"), "this is a pdf")
    File.write(Config.receive_folder.join("with space.txt"), "this has a space")

    assert_difference -> { ReceivedFile.count }, +3 do
      ["sample.zip", "sub/sample.pdf", "with space.txt"].each { |file| Receiver::StoreFileJob.perform_now(file) }
    end

    assert_file_list([], Config.receive_folder)
    assert_file_list(["1.txt", "sample.zip", "sub/sample.pdf", "with space.txt"], Config.storage_folder)
    assert_equal 13, ReceivedFile.find_by!(path: "sample.zip").size
  end

  test "relay received files" do
    set_config("MODE", "receiver")
    set_config("RELAY_FOLDER", RELAY_FOLDER)
    File.write(Config.receive_folder.join("sample.pdf"), "this is a pdf")

    Receiver::StoreFileJob.perform_now("sample.pdf")

    assert_file_list(["1.txt", "sample.pdf"], Config.storage_folder)
    assert_file_list(["sample.pdf"], RELAY_FOLDER)
  end

  test "store a file only once" do
    File.write(Config.receive_folder.join("sample.zip"), "this is a zip")

    assert_difference -> { ReceivedFile.count }, +1 do
      2.times { Receiver::StoreFileJob.perform_now("sample.zip") }
    end
  end

  test "fail when the file can't be copied" do
    File.write(Config.receive_folder.join("sample.zip"), "this is a zip")
    FileUtils.chmod(0o000, Config.receive_folder.join("sample.zip"))
    skip "Running as root, permissions aren't enforced" if File.readable?(Config.receive_folder.join("sample.zip"))

    assert_raises(RuntimeError) { Receiver::StoreFileJob.perform_now("sample.zip") }
    assert_equal 0, ReceivedFile.where(path: "sample.zip").count
  ensure
    FileUtils.chmod(0o644, Config.receive_folder.join("sample.zip"))
  end
end
