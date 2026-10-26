module Sender
  class Send
    def self.send(source_path, files, target_path, sync)
      progress_step = (1.0 / files.count * 100.0)
      progress = 0.0
      finish = Proc.new do |_file, _index, result|
        progress += progress_step
        sync.progress = progress.round
        sync.increment(:bytes_transferred, result[:size])
        sync.save if sync.progress_changed?
      end

      sent_files = Parallel.map_with_index(files, finish: finish) do |file, index|
        # rsync -R keeps the relative path of the file, so it needs to run inside the source folder.
        # Use spawn's chdir instead of Dir.chdir, which is process-wide and jobs run in multiple threads.
        system("rsync", "-Rt", file, target_path.to_s, chdir: source_path.to_s)
        { path: file, size: File.size(File.join(source_path, file)), sync_id: sync.id}
      end

      SentFile.insert_all(sent_files) unless sent_files.empty?
      sync.increment(:progress, 100.0) if files.empty?
      sync.save
    end
  end
end
