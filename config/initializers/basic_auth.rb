if Rails.env.production? && ENV['SECRET_KEY_BASE'] != 'buildingassets'
  Rails.application.config.synchronist_username = ENV["SYNCHRONIST_USERNAME"].presence || "synchronist"
  Rails.application.config.synchronist_password = ENV["SYNCHRONIST_PASSWORD"].presence or
    abort "SYNCHRONIST_PASSWORD must be set to protect the web interface"
else
  Rails.application.config.synchronist_username = "sync"
  Rails.application.config.synchronist_password = "sync"
end
