require "test_helper"

class BenchmarkTest < ActiveSupport::TestCase
  BENCHMARK_SOURCE_RELATIVE_PATH = "tmp/benchmark"
  BENCHMARK_SOURCE_PATH = Rails.root.join(BENCHMARK_SOURCE_RELATIVE_PATH)
  BENCHMARK_SOURCE_DEPTH = 5
  BENCHMARK_SOURCE_FILES = 100_000
  BENCHMARK_SEND_PATH = Rails.root.join("tmp/benchmark-send")
  BENCHMARK_SEND_SAMPLE_SIZE = 1000

  setup do
    if ENV.key?("SYNCHRONIST_TEST_BENCHMARK") && !Dir.exist?(BENCHMARK_SOURCE_PATH)
      print "Generating sample directory (#{BENCHMARK_SOURCE_DEPTH} levels, #{BENCHMARK_SOURCE_FILES} files) in #{BENCHMARK_SOURCE_RELATIVE_PATH} ... "
      create_directories(BENCHMARK_SOURCE_PATH, BENCHMARK_SOURCE_DEPTH, BENCHMARK_SOURCE_FILES)
      puts "done"
    end
    FileUtils.rm_rf BENCHMARK_SEND_PATH
    FileUtils.mkdir_p BENCHMARK_SEND_PATH
  end

  test "benchmark payload generate" do
    skip_unless_benchmarking

    Benchmark.bm do |x|
      x.report("Generate payload") do
        Receiver::Payload.generate("1234", path: BENCHMARK_SOURCE_PATH)
      end
    end
  end

  test "benchmark diffing" do
    skip_unless_benchmarking

    payload_files = PayloadFile.load(Receiver::Payload.generate("1234", path: BENCHMARK_SOURCE_PATH))[:files]
    Benchmark.bm do |x|
      x.report("Diff files") do
        Sender::Diff.diff(BENCHMARK_SOURCE_PATH, payload_files)
      end
    end
  end

  test "benchmark send" do
    skip_unless_benchmarking

    sync = Sync.create!(sender_payload: Sender::Payload.create!(uid: "1234", mtime: Time.now, received_at: Time.now))
    files = PayloadFile.load(Receiver::Payload.generate("1234", path: BENCHMARK_SOURCE_PATH))[:files].keys.first(BENCHMARK_SEND_SAMPLE_SIZE)
    Benchmark.bm do |x|
      x.report("Send files") do
        Sender::Send.send(BENCHMARK_SOURCE_PATH, files, BENCHMARK_SOURCE_PATH, sync)
      end
    end
  end

  private
  def create_directories(base_path, depth, file_count)
    if depth == 0
      # Create the files at this level
      file_count.times do |i|
        File.write(File.join(base_path, "file_#{i}.txt"), "Content for file #{i}")
      end
      return
    end

    # Number of directories at this level
    dir_count = BENCHMARK_SOURCE_DEPTH

    # Distribute files evenly across directories
    files_per_dir = file_count / dir_count

    dir_count.times do |i|
      dir_path = File.join(base_path, "dir_#{i}")
      FileUtils.mkdir_p(dir_path)
      create_directories(dir_path, depth - 1, files_per_dir)
    end
  end

  def skip_unless_benchmarking
    skip "Use bin/benchmark to run benchmarks" unless ENV.key?("SYNCHRONIST_TEST_BENCHMARK")
  end
end
