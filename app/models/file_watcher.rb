require "listen"

# Watches a folder with listen (inotify on Linux) and yields the path (relative to the folder) of
# each new or changed file once it's completely written: Its size and mtime didn't change for
# `settle_seconds`. A file that's still being copied into the folder is yielded only once, after
# the copy finished.
class FileWatcher
  # Listen takes its initial snapshot of the folder in the background and doesn't report files that
  # are added while it's doing so. The folder is scanned again after this delay to not miss them.
  STARTUP_RESCAN_DELAY = 5

  attr_reader :folder

  def initialize(folder, settle_seconds:, only: nil, force_polling: false, rescan_delay: STARTUP_RESCAN_DELAY, &on_file)
    @folder = Pathname.new(folder)
    @settle_seconds = settle_seconds
    @only = only
    @force_polling = force_polling
    @rescan_delay = rescan_delay
    @on_file = on_file
    @pending = {}
    @yielded = {}
    @mutex = Mutex.new
  end

  # Runs the watcher for the configured mode in the background:
  # - Receiver: Store files arriving in the receive folder.
  # - Sender: Process the payload whenever it changes.
  def self.start
    unless Config.configured?
      return Rails.logger.error("Not watching for incoming files: #{Config.errors.to_sentence}")
    end

    @watcher = if Config.receiver?
      new(Config.receive_folder, **options) { |file| Receiver::StoreFileJob.perform_later(file) }
    else
      new(Config.payload_path.dirname, only: Config.payload_path.basename.to_s, **options) { Sender::CheckPayloadPathJob.perform_later }
    end
    @watcher.start
  end

  def self.stop
    @watcher&.stop
  end

  def self.options
    { settle_seconds: Config.settle_seconds, force_polling: Config.watcher_polling? }
  end

  def start
    unless folder.directory?
      return Rails.logger.error("Not watching #{folder}, it's not a directory")
    end

    @folder = folder.realpath
    Rails.logger.info("Watching #{folder} for incoming files#{" (polling)" if @force_polling}")

    options = { force_polling: @force_polling }
    # Don't pass `only: nil`, listen ignores all changes then
    options[:only] = /\A#{Regexp.escape(@only)}\z/ if @only
    @listener = Listen.to(folder.to_s, **options) do |modified, added, removed|
      (modified + added).each { |path| track(relative(path)) }
      removed.each { |path| forget(relative(path)) }
    end
    @listener.start

    # Pick up the files that arrived while synchronist wasn't running
    scan
    rescan_at = now + @rescan_delay

    @settler = Thread.new do
      loop do
        sleep 1
        if rescan_at && now >= rescan_at
          scan
          rescan_at = nil
        end
        settle
      rescue StandardError => e
        Rails.logger.error("FileWatcher: #{e.full_message}")
      end
    end
  end

  def stop
    @listener&.stop
    @settler&.kill
  end

  def scan
    Dir.glob("**/*", base: folder).each { |file| track(file) }
  end

  def track(file)
    return if @only && file != @only

    @mutex.synchronize { @pending[file] ||= nil }
  end

  def forget(file)
    @mutex.synchronize do
      @pending.delete(file)
      @yielded.delete(file)
    end
  end

  # Yields all tracked files that didn't change for `settle_seconds`
  def settle(now: self.now)
    settled = []
    @mutex.synchronize do
      @pending.keys.each do |file|
        stat = File.stat(folder.join(file)) rescue nil
        unless stat&.file?
          @pending.delete(file)
          @yielded.delete(file)
          next
        end

        signature = [stat.size, stat.mtime]
        if @pending[file].nil? || @pending[file][:signature] != signature
          @pending[file] = { signature: signature, changed_at: now }
        elsif now - @pending[file][:changed_at] >= @settle_seconds
          @pending.delete(file)
          # Already yielded and unchanged since, e.g. reported again by a scan
          next if @yielded[file] == signature

          @yielded[file] = signature
          settled << file
        end
      end
    end

    Rails.application.reloader.wrap { settled.each { |file| @on_file.call(file) } } if settled.any?
  end

  private
  def relative(path)
    Pathname.new(path).relative_path_from(folder).to_s
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
