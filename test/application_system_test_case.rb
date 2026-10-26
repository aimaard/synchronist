require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  setup do
    login
  end

  protected
  # Send basic auth credentials as a header instead of embedding them in the URL
  # (http://user:pass@host), which makes Turbo's history.replaceState fail.
  def login
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("sync", "sync")
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setExtraHTTPHeaders", headers: { "Authorization" => credentials })
    visit root_url
  end
end
