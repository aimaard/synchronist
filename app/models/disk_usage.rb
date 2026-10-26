class DiskUsage
  def self.size(path)
    return 0 unless File.directory?(path)

    IO.popen(["du", "-sb", path.to_s], &:read).to_i
  end
end
