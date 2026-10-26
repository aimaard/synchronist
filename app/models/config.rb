# Synchronist is configured with SYNCHRONIST_* environment variables (see README.md).
class Config
  DEFAULT_SYNC_CRON = "0 */6 * * *"
  MODES = %w[sender receiver].freeze

  # Environment variable (without the SYNCHRONIST_ prefix) => description, per mode
  SENDER_SETTINGS = {
    "PAYLOAD_PATH" => "Payload file received from the receiver",
    "SOURCE_FOLDER" => "Folder to mirror",
    "SEND_FOLDER" => "Folder to put the missing/changed files into",
  }.freeze

  RECEIVER_SETTINGS = {
    "PAYLOAD_PATH" => "Payload file to send to the sender",
    "STORAGE_FOLDER" => "Folder holding the mirrored files",
    "RECEIVE_FOLDER" => "Folder the files from the sender arrive in",
    "RELAY_FOLDER" => "Optional: Also copy all received files into this folder",
    "SYNC_CRON" => "How often to send a payload to the sender",
  }.freeze

  OPTIONAL_SETTINGS = %w[RELAY_FOLDER SYNC_CRON].freeze

  class << self
    def mode
      env("MODE")&.downcase
    end

    def sender?
      mode == "sender"
    end

    def receiver?
      mode == "receiver"
    end

    def relay?
      receiver? && relay_folder.present?
    end

    def payload_path = path("PAYLOAD_PATH")
    def source_folder = path("SOURCE_FOLDER")
    def send_folder = path("SEND_FOLDER")
    def storage_folder = path("STORAGE_FOLDER")
    def receive_folder = path("RECEIVE_FOLDER")
    def relay_folder = path("RELAY_FOLDER")

    def sync_cron
      env("SYNC_CRON") || DEFAULT_SYNC_CRON
    end

    def settings
      case mode
      when "sender" then SENDER_SETTINGS
      when "receiver" then RECEIVER_SETTINGS
      else {}
      end
    end

    def configured?
      errors.empty?
    end

    # Problems that prevent synchronist from running
    def errors
      return ["#{key("MODE")} must be set to \"sender\" or \"receiver\""] unless MODES.include?(mode)

      errors = (settings.keys - OPTIONAL_SETTINGS).filter_map do |name|
        "#{key(name)} must be set" if env(name).nil?
      end
      errors << "#{key("SYNC_CRON")} \"#{sync_cron}\" is not a valid cron expression" if receiver? && Fugit::Cron.parse(sync_cron).nil?
      errors
    end

    # Problems with the file system, e.g. a volume that isn't mounted
    def warnings
      return [] unless configured?

      folders = settings.keys.select { |name| name.end_with?("_FOLDER") && env(name) }
      warnings = folders.filter_map do |name|
        "#{key(name)} (#{env(name)}) is not a directory" unless File.directory?(env(name))
      end
      warnings << "The folder of #{key("PAYLOAD_PATH")} (#{payload_path.dirname}) is not a directory" unless File.directory?(payload_path.dirname)
      warnings
    end

    def key(name)
      "SYNCHRONIST_#{name}"
    end

    def env(name)
      ENV[key(name)].presence
    end

    private
    def path(name)
      value = env(name)
      Pathname.new(value) if value
    end
  end
end
