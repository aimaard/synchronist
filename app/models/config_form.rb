class ConfigForm
  include ActiveModel::Model

  attr_accessor(:receiver_send_payload_cron, *Config::CONFIGS)
  validates :mode, presence: true
  validates :receiver_send_payload_cron, presence: true
  validates_presence_of(*Config::SENDER_CONFIGS, if: -> { mode == "sender" })
  validates_presence_of(*Config::RECEIVER_CONFIGS, if: -> { mode == "receiver" })
  validates_presence_of(*Config::RELAY_CONFIGS, if: -> { mode == "receiver" && receiver_relay_mode.to_s == "1" })
  validate :validate_cron

  def receiver_send_payload_cron
    @receiver_send_payload_cron || "0 */6 * * *"
  end

  def self.current
    new(Hash[Config.all.pluck(:name, :value)])
  end

  def save
    return false unless valid?

    Config.transaction do
      Config::CONFIGS.each do |attr|
        Config.set!(name: attr, value: public_send(attr))
      end

      schedule_recurring_tasks
    end
    true
  end

  def schedule_recurring_tasks
    SolidQueue::RecurringTask.dynamic.delete_all
    return unless Config.configured?

    if mode == "sender"
      SolidQueue.schedule_recurring_task(
        "sender_check_payload",
        class: Sender::CheckPayloadPathJob.to_s,
        schedule: ENV.fetch("SYNCHRONIST_CHECK_PAYLOAD_CRON", "* * * * *"),
        description: "Sender: Check payload"
      )
    elsif mode == "receiver"
      SolidQueue.schedule_recurring_task(
        "receiver_send_payload",
        class: Receiver::SendPayloadJob.to_s,
        schedule: receiver_send_payload_cron,
        description: "Receiver: Generate and send payload of current storage folder"
      )
      SolidQueue.schedule_recurring_task(
        "receiver_check_received_files",
        class: Receiver::CheckReceiveFolderJob.to_s,
        schedule: ENV.fetch("SYNCHRONIST_CHECK_RECEIVED_FILES_CRON", "* * * * *"),
        description: "Receiver: Check for received files and put them into storage folder"
      )
    end
  end

  def validate_cron
    if Fugit::Cron.parse(receiver_send_payload_cron).blank?
      errors.add(:receiver_send_payload_cron, "Invalid cron expression")
    end
  end
end
