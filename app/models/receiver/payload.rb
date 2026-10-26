module Receiver
  class Payload < ApplicationRecord
    self.table_name_prefix = "receiver_"

    has_one_attached :file
    broadcasts inserts_by: :prepend

    validates :sent_at, presence: true
    scope :ordered, -> { order(sent_at: :desc) }
    before_create :generate_uid

    def self.generate(uid, path: Config.storage_folder)
      # Avoid Dir.chdir: it is process-wide and jobs run in multiple threads.
      files = Dir.glob("**/*", base: path).each_with_object({}) do |file, memo|
        full_path = File.join(path, file)
        memo[file] = File.mtime(full_path).to_i if File.file?(full_path)
      end

      PayloadFile.dump(uid: uid, files: files)
    end

    def self.send!
      payload_path = Config.payload_path
      created = create!(sent_at: Time.now)

      File.write(payload_path, generate(created.uid))
      File.open(payload_path, "r") do |f|
        created.file.attach(
          io: f,
          filename: File.basename(payload_path)
        )
      end
    end

    def generate_uid
      if Rails.env.test?
        self.uid = :testing
      else
        self.uid = SecureRandom.hex(6)
      end
    end
  end
end
