source "https://rubygems.org"

ruby "~> 4.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.10"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 8.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", ">= 2.2"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", ">= 2.0"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", ">= 1.3"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Active Job and Action Cable
gem "solid_queue", ">= 1.7"
gem "solid_cable", ">= 4.1"

# Web UI for inspecting Solid Queue jobs (mounted at /jobs)
gem "mission_control-jobs", ">= 1.3"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem "cssbundling-rails", ">= 1.4"
gem "bootstrap_form", ">= 5.6"
gem "rails-i18n", ">= 8.0"
gem "parallel"
gem "fugit"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "benchmark"
end
