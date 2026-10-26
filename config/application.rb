require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Synchronist
  class Application < Rails::Application
    config.load_defaults 7.0

    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }
    # Protect the jobs dashboard with the app's own basic auth
    config.mission_control.jobs.base_controller_class = "ApplicationController"
    config.mission_control.jobs.http_basic_auth_enabled = false
    config.action_mailer.deliver_later_queue_name = nil
    config.action_mailbox.queues.routing    = nil
    config.active_storage.queues.analysis   = nil
    config.active_storage.queues.purge      = nil
    config.active_storage.queues.mirror     = nil
    # Only payload files are stored, no image variants needed
    config.active_storage.variant_processor = :disabled

    config.i18n.available_locales = [:en]
    config.i18n.locale = :en

    config.time_zone = ENV.fetch("RAILS_TIMEZONE", "Europe/Zurich")
    config.version = "1.0.0.beta3"
  end
end
