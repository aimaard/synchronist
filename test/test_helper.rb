ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Disable parallel tests because they're mostly based on files
  # parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  OUTDATED_MTIME = Time.parse("1990-01-01 13:00:00 UTC")
  OUTDATED_MTIME_TIMESTAMP = OUTDATED_MTIME.to_i
  BASE_MTIME = Time.parse("2022-11-01 13:00:00 UTC")
  BASE_MTIME_TIMESTAMP = BASE_MTIME.to_i

  FIXTURE_DATA = Rails.root.join("test/fixtures/data")
  RELAY_FOLDER = FIXTURE_DATA.join("receiver/relay")
  CONFIG = {
    "SYNCHRONIST_MODE" => "sender",
    "SYNCHRONIST_PAYLOAD_PATH" => FIXTURE_DATA.join("payload.synchronist").to_s,
    "SYNCHRONIST_SOURCE_FOLDER" => FIXTURE_DATA.join("sender/source").to_s,
    "SYNCHRONIST_SEND_FOLDER" => FIXTURE_DATA.join("sender/send").to_s,
    "SYNCHRONIST_STORAGE_FOLDER" => FIXTURE_DATA.join("receiver/storage").to_s,
    "SYNCHRONIST_RECEIVE_FOLDER" => FIXTURE_DATA.join("receiver/receive").to_s,
  }.freeze

  setup do
    @original_env = ENV.to_h
    ENV.update(CONFIG)

    Dir.glob(Config.source_folder.join("**/*")) do |file|
      FileUtils.touch(file, mtime: BASE_MTIME)
    end

    Dir.glob(Config.storage_folder.join("**/*")) do |file|
      FileUtils.touch(file, mtime: BASE_MTIME)
    end
    FileUtils.rm_f(Config.payload_path)
    FileUtils.rm_rf(Config.send_folder)
    FileUtils.mkdir_p(Config.send_folder)
    FileUtils.rm_rf(Config.receive_folder)
    FileUtils.mkdir_p(Config.receive_folder)
    FileUtils.rm_rf(RELAY_FOLDER)
    FileUtils.mkdir_p(RELAY_FOLDER)
    FileUtils.rm_rf Dir.glob(Config.storage_folder.join('**/*')).reject { |f| File.basename(f) == "1.txt" }
  end

  teardown do
    ENV.replace(@original_env)
  end

  def set_config(name, value)
    ENV[Config.key(name)] = value&.to_s
  end

  def assert_file_list(expected, dir)
    assert_equal(expected, Dir.glob("**/*", base: dir).select { |file| File.file?(File.join(dir, file)) }.sort)
  end
end
