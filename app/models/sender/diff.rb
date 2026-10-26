module Sender
  class Diff
    def self.diff(source_path, payload_files)
      # Avoid Dir.chdir: it is process-wide and jobs run in multiple threads.
      Dir.glob("**/*", base: source_path).each_with_object([]) do |file, memo|
        full_path = File.join(source_path, file)
        next unless File.file?(full_path)

        memo << file if !payload_files.key?(file) || payload_files[file] < File.mtime(full_path).to_i
      end
    end
  end
end
