require "application_system_test_case"

class ConfigTest < ApplicationSystemTestCase
  test "show the configuration" do
    visit config_path

    within "#configuration" do
      assert_text "SYNCHRONIST_MODE sender"
      assert_text "SYNCHRONIST_SOURCE_FOLDER"
      assert_text CONFIG["SYNCHRONIST_SOURCE_FOLDER"]
      assert_no_text "SYNCHRONIST_STORAGE_FOLDER"
    end
  end

  test "show configuration errors" do
    set_config("MODE", "receiver")
    set_config("STORAGE_FOLDER", nil)

    visit root_path

    assert_current_path config_path
    assert_text "SYNCHRONIST_STORAGE_FOLDER must be set"
  end

  test "warn about missing folders" do
    set_config("SOURCE_FOLDER", "/does/not/exist")

    visit root_path

    assert_text "SYNCHRONIST_SOURCE_FOLDER (/does/not/exist) is not a directory. Check the configuration"
  end
end
