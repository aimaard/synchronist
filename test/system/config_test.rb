require "application_system_test_case"

class ConfigTest < ApplicationSystemTestCase
  test "setup sender application" do
    visit edit_config_path
    choose "Sender"
    fill_in "Payload Path", with: "/tmp/payload.sync"
    fill_in "Source Folder", with: "/data/apt-mirror"
    fill_in "Send Folder", with: "/mnt/samba-to-receiver"

    click_on "Save"
    assert_text "Configuration saved!"

    assert_equal("sender", Config.get!("mode"))
    assert_equal("/tmp/payload.sync", Config.get!("sender_payload_path").to_s)
    assert_equal("/data/apt-mirror", Config.get!("sender_source_folder").to_s)
    assert_equal("/mnt/samba-to-receiver", Config.get!("sender_send_folder").to_s)
  end

  test "setup receiver application" do
    visit edit_config_path
    choose "Receiver"
    fill_in "Synchronization cron", with: "0 */12 * * *"
    fill_in "Payload Path", with: "/mnt/smb/to-sender/payload.sync"
    fill_in "Storage Folder", with: "/data/mirrors/apt-mirror"
    fill_in "Receive Folder", with: "/mnt/smb/from-sender"
    check "Relay mode"
    fill_in "Relay folder", with: "/mnt/relay"

    assert_difference -> { SolidQueue::RecurringTask.count }, +2 do
      click_on "Save"
      assert_text "Configuration saved!"
    end

    assert_equal("receiver", Config.get!("mode"))
    assert(Config.relay?)
    assert_equal("/mnt/smb/to-sender/payload.sync", Config.get!("receiver_payload_path").to_s)
    assert_equal("/data/mirrors/apt-mirror", Config.get!("receiver_storage_folder").to_s)
    assert_equal("/mnt/smb/from-sender", Config.get!("receiver_receive_folder").to_s)
    assert_equal("/mnt/relay", Config.get!("receiver_relay_folder").to_s)
  end
end
