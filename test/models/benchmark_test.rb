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

  # Shows how big the payload gets for a big mirror, compared to plain JSON
  PAYLOAD_SIZE_PATH = Rails.root.join("tmp/benchmark-payload-size")
  PAYLOAD_SIZE_FILES = Integer(ENV.fetch("SYNCHRONIST_BENCHMARK_PAYLOAD_FILES", 1_250_000))

  test "benchmark payload size" do
    skip_unless_benchmarking
    create_mirror(PAYLOAD_SIZE_PATH, PAYLOAD_SIZE_FILES) unless Dir.exist?(PAYLOAD_SIZE_PATH)

    payload = nil
    generate_time = Benchmark.realtime { payload = Receiver::Payload.generate("1234", path: PAYLOAD_SIZE_PATH) }
    files = nil
    load_time = Benchmark.realtime { files = PayloadFile.load(payload)[:files] }
    json = JSON.generate({ uid: "1234", files: files })

    assert_equal PAYLOAD_SIZE_FILES, files.size
    puts
    puts "Payload of #{files.size.to_fs(:delimited)} files (generated in #{generate_time.round(1)}s, loaded in #{load_time.round(1)}s):"
    puts "  JSON:         #{json.bytesize.to_fs(:human_size, precision: 4)}"
    puts "  gzipped JSON: #{payload.bytesize.to_fs(:human_size, precision: 4)} (#{(json.bytesize.to_f / payload.bytesize).round(1)}x smaller)"
    assert_operator payload.bytesize, :<, json.bytesize / 3
  end

  private
  # Creates (empty) files with paths and mtimes like in a package mirror
  def create_mirror(base_path, file_count)
    print "Generating mirror (#{file_count.to_fs(:delimited)} files) in #{base_path.relative_path_from(Rails.root)} ... "
    random = Random.new(42)
    syllables = %w[ba be bi bo bu ca co cu da de di do el en er fa fe fi ga ge go ha he in io ka ke ki la le li lo lu ma me mi mo na ne no nu on or pa pe pi po ra re ri ro ru sa se si so ta te ti to tu un va ve vi xa xe ya yo za ze zo]
    prefixes = ["", "", "", "lib", "python3-", "golang-", "node-", "r-cran-", "fonts-"]
    # About 20 files (versions, architectures) per package, like in a Debian mirror
    packages = Array.new(file_count / 20 + 1) do
      prefixes.sample(random: random) + Array.new(random.rand(2..4)) { syllables.sample(random: random) }.join + (random.rand(4).zero? ? random.rand(1..9).to_s : "")
    end
    arches = %w[amd64 arm64 armhf i386 all]
    created = 0
    while created < file_count
      package = packages.sample(random: random)
      version = "#{random.rand(10)}.#{random.rand(30)}.#{random.rand(100)}-#{random.rand(5)}"
      dir = File.join(base_path, "pool", %w[main contrib non-free].sample(random: random), package.start_with?("lib") ? package[0, 4] : package[0], package)
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{package}_#{version}_#{arches.sample(random: random)}.deb")
      next if File.exist?(path)

      File.write(path, "")
      created += 1
      mtime = Time.at(1_500_000_000 + random.rand(300_000_000))
      File.utime(mtime, mtime, path)
    end
    puts "done"
  end

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
