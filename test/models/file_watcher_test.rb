require "test_helper"

class FileWatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @files = Queue.new
    @watcher = FileWatcher.new(Config.receive_folder, settle_seconds: 10) { |file| @files << file }
  end

  teardown do
    @watcher.stop
  end

  test "yield a file once it didn't change for the settle time" do
    File.write(Config.receive_folder.join("big.iso"), "part 1")
    @watcher.track("big.iso")

    @watcher.settle(now: 0)
    @watcher.settle(now: 9)
    assert_empty @files

    # Still being written
    File.write(Config.receive_folder.join("big.iso"), "part 1, part 2")
    @watcher.track("big.iso")
    @watcher.settle(now: 9.5)
    @watcher.settle(now: 15)
    assert_empty @files

    @watcher.settle(now: 19.5)
    assert_equal ["big.iso"], drain

    # Only once, even if the file is reported again before it's stored
    @watcher.track("big.iso")
    @watcher.settle(now: 30)
    @watcher.settle(now: 31)
    assert_empty @files
  end

  test "yield a file again when it's replaced" do
    File.write(Config.receive_folder.join("payload"), "first")
    @watcher.track("payload")
    @watcher.settle(now: 0)
    @watcher.settle(now: 10)
    assert_equal ["payload"], drain

    File.write(Config.receive_folder.join("payload"), "second payload")
    @watcher.track("payload")
    @watcher.settle(now: 20)
    @watcher.settle(now: 30)
    assert_equal ["payload"], drain
  end

  test "ignore files that are gone before they settled" do
    File.write(Config.receive_folder.join(".tmp-file"), "temporary")
    @watcher.track(".tmp-file")
    @watcher.settle(now: 0)
    FileUtils.rm(Config.receive_folder.join(".tmp-file"))

    @watcher.settle(now: 20)
    assert_empty @files
  end

  test "only watch a single file" do
    watcher = FileWatcher.new(Config.receive_folder, settle_seconds: 0, only: "payload.synchronist") { |file| @files << file }
    File.write(Config.receive_folder.join("payload.synchronist"), "payload")
    File.write(Config.receive_folder.join("other"), "other")
    watcher.track("payload.synchronist")
    watcher.track("other")

    2.times { |i| watcher.settle(now: i) }
    assert_equal ["payload.synchronist"], drain
  end

  test "pick up existing and new files" do
    File.write(Config.receive_folder.join("existing.txt"), "was here before")
    # Without the rescan, new files can only be picked up by listening for changes
    watcher = FileWatcher.new(Config.receive_folder, settle_seconds: 0.5, rescan_delay: 1.hour) { |file| @files << file }
    watcher.start
    assert_equal "existing.txt", @files.pop(timeout: 10)

    FileUtils.mkdir_p(Config.receive_folder.join("sub"))
    File.write(Config.receive_folder.join("sub/new.txt"), "new")
    File.write(Config.receive_folder.join("new.txt"), "new")

    files = 2.times.map { @files.pop(timeout: 10) }
    assert_equal ["new.txt", "sub/new.txt"], files.compact.sort
  ensure
    watcher&.stop
  end

  test "pick up files added while listen is starting" do
    watcher = FileWatcher.new(Config.receive_folder, settle_seconds: 0, rescan_delay: 2) { |file| @files << file }
    watcher.start
    FileUtils.mkdir_p(Config.receive_folder.join("sub"))
    File.write(Config.receive_folder.join("sub/new.txt"), "new")

    assert_equal "sub/new.txt", @files.pop(timeout: 10)
  ensure
    watcher&.stop
  end

  test "start the watcher for the receiver" do
    set_config("MODE", "receiver")
    File.write(Config.receive_folder.join("sample.zip"), "this is a zip")
    set_config("SETTLE_SECONDS", "0")

    FileWatcher.start

    wait_until { enqueued_jobs.any? }
    assert_enqueued_with(job: Receiver::StoreFileJob, args: ["sample.zip"])
  ensure
    FileWatcher.stop
  end

  private
  def drain
    Array.new(@files.size) { @files.pop }
  end

  def wait_until(timeout: 10)
    deadline = Time.now + timeout
    sleep 0.1 until yield || Time.now > deadline
  end
end
