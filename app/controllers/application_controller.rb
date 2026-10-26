class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: Rails.application.config.synchronist_username, password: Rails.application.config.synchronist_password

  before_action :check_configuration

  private
  def check_configuration
    return if Config.configured?

    redirect_to config_path, alert: "Synchronist isn't configured correctly, please set the environment variables listed below."
  end
end
