module Sender
  class CheckPayloadPathJob < ApplicationJob
    # The payload is only processed once, even when the watcher notices multiple changes
    limits_concurrency key: "sender_payload", on_conflict: :discard

    def perform
      payload_path = Config.payload_path

      if File.file?(payload_path) && (
           Sender::Payload.exists? ? File.mtime(payload_path).to_i > Sender::Payload.ordered.first.mtime.to_i : true
         )
        Sender::ProcessPayloadJob.perform_later(
          Sender::Payload.receive!(payload_path),
          Config.source_folder.to_s,
          Config.send_folder.to_s,
        )
      end
    end
  end
end
