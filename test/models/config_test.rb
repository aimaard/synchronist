require "test_helper"

class ConfigTest < ActiveSupport::TestCase
  test "configured sender" do
    assert Config.configured?
    assert Config.sender?
    assert_equal Pathname.new(CONFIG["SYNCHRONIST_SOURCE_FOLDER"]), Config.source_folder
    assert_empty Config.warnings
  end

  test "configured receiver" do
    set_config("MODE", "Receiver")

    assert Config.configured?
    assert Config.receiver?
    assert_not Config.relay?
    assert_equal "0 */6 * * *", Config.sync_cron

    set_config("RELAY_FOLDER", RELAY_FOLDER)
    assert Config.relay?
  end

  test "mode is required" do
    set_config("MODE", nil)
    assert_equal ['SYNCHRONIST_MODE must be set to "sender" or "receiver"'], Config.errors

    set_config("MODE", "relay")
    assert_equal ['SYNCHRONIST_MODE must be set to "sender" or "receiver"'], Config.errors
  end

  test "required settings" do
    set_config("SEND_FOLDER", "")
    assert_equal ["SYNCHRONIST_SEND_FOLDER must be set"], Config.errors

    set_config("MODE", "receiver")
    set_config("RECEIVE_FOLDER", nil)
    set_config("SYNC_CRON", "every full moon")
    assert_equal [
      "SYNCHRONIST_RECEIVE_FOLDER must be set",
      'SYNCHRONIST_SYNC_CRON "every full moon" is not a valid cron expression',
    ], Config.errors
  end

  test "warn about missing folders" do
    set_config("SOURCE_FOLDER", "/does/not/exist")
    set_config("PAYLOAD_PATH", "/not/mounted/payload.synchronist")

    assert Config.configured?
    assert_equal [
      "SYNCHRONIST_SOURCE_FOLDER (/does/not/exist) is not a directory",
      "The folder of SYNCHRONIST_PAYLOAD_PATH (/not/mounted) is not a directory",
    ], Config.warnings
  end
end
