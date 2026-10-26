module Receiver
  class CheckReceiveFolderJob < ApplicationJob
    def perform
      folder = Config.receive_folder
      unless File.directory?(folder)
        return Rails.logger.warn("Receive folder is not a valid directory, please check your configuration")
      end

      Dir.glob("**/*", base: folder).select { |file| File.file?(File.join(folder, file)) }.each do |file|
        StoreFileJob.perform_later(file)
      end
    end
  end
end
