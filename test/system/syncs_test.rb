require "application_system_test_case"

class SyncsTest < ApplicationSystemTestCase
  test "View sync" do
    visit syncs_path
    click_on syncs(:pending).id.to_s
    assert_equal "56%", find(".progress-bar").text
    assert_equal "Started at: December 01, 2022 01:00", find(".started-at").text
    assert_file_list(
      [
        ["sample.zip", "11.8 KB"]
      ]
    )


    visit syncs_path
    click_on syncs(:errored).id.to_s
    assert_equal "76%", find(".progress-bar").text
    assert_equal "Started at: January 01, 2022 01:00", find(".started-at").text
    assert_equal "Errored at: January 01, 2022 02:01", find(".errored-at").text
    assert_includes find(".alert-danger").text, "rsa#set_key= is incompatible with OpenSSL 3.0"
    assert_file_list(
      [
        ["docker-nginx.tar", "114 MB"]
      ]
    )

    visit syncs_path
    click_on syncs(:done).id.to_s
    assert_equal "100%", find(".progress-bar").text
    assert_equal "Started at: February 01, 2022 01:00", find(".started-at").text
    assert_equal "Finished at: February 01, 2022 01:00", find(".finished-at").text
    assert_file_list(
      [
        ["1.txt", "20 Bytes"],
        ["2.txt", "40 Bytes"]
      ]
    )
  end

  test "filter files" do
    visit sync_path(syncs(:done))

    filter_files "1.tx"
    assert_file_list([["1.txt", "20 Bytes"]])

    filter_files "no-exist-file"
    assert_file_list([])

    click_on "Reset filter"
    assert_no_text "No files found containing"
    assert_file_list(
      [
        ["1.txt", "20 Bytes"],
        ["2.txt", "40 Bytes"],
      ]
    )
  end

  private
  def filter_files(filename)
    fill_in "filename", with: filename
    find(:fillable_field, "filename").native.send_keys :enter
    assert_current_path(/filename=#{Regexp.escape(filename)}/)
  end

  def assert_file_list(expected)
    actual = []
    all(".file-list li").each do |entry|
      actual << [entry.find(".filename").text, entry.find(".filesize").text]
    end
    assert_equal expected, actual
  end
end
