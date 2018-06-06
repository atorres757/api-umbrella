require_relative "../test_helper"

class Test::AdminUi::TestStatsLogs < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::DateRangePicker
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_xss_escaping_in_table
    log = FactoryBot.create(:xss_log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_method => "OPTIONS")
    LogItem.gateway.refresh_index!

    admin_login
    visit "/admin/#/stats/logs?search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")

    assert_text(log.request_method)
    assert_text(log.request_accept_encoding)
    assert_text(log.request_ip_city)
    assert_text(log.request_ip_country)
    assert_text(log.request_ip_region)
    assert_text(log.request_user_agent)
    assert_text(log.response_content_type)
    assert_text(log.user_email)
    refute_selector(".xss-test", :visible => :all)
  end

  def test_csv_download_link_changes_with_filters
    FactoryBot.create(:log_item, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc)
    LogItem.gateway.refresh_index!
    default_query = JSON.generate({
      "condition" => "AND",
      "rules" => [{
        "field" => "gatekeeper_denied_code",
        "id" => "gatekeeper_denied_code",
        "input" => "select",
        "operator" => "is_null",
        "type" => "string",
        "value" => nil,
      }],
    })

    admin_login
    visit "/admin/#/stats/logs?search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-12/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "search" => "",
      "start_at" => "2015-01-12",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => default_query,
    }, uri.query_values)

    visit "/admin/#/stats/logs?search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-13/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "search" => "",
      "start_at" => "2015-01-13",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => default_query,
    }, uri.query_values)

    visit "/admin/#/stats/logs?search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-12/)
    assert_link("Download CSV", :href => /#{Regexp.escape(CGI.escape('"rules":[{'))}/)
    click_button "Delete" # Remove the initial filter
    click_button "Filter"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /#{Regexp.escape(CGI.escape('"rules":[]'))}/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "start_at" => "2015-01-12",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => JSON.generate({ "condition" => "AND", "rules" => [], "valid" => true }),
      "search" => "",
    }, uri.query_values)

    visit "/admin/#/stats/logs?search=&start_at=2015-01-13&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /start_at=2015-01-13/)
    find("a", :text => /Switch to advanced filters/).click
    fill_in "search", :with => "response_status:200"
    click_button "Filter"
    refute_selector(".busy-blocker")
    assert_link("Download CSV", :href => /response_status%3A200/)
    link = find_link("Download CSV")
    uri = Addressable::URI.parse(link[:href])
    assert_equal("/admin/stats/logs.csv", uri.path)
    assert_equal({
      "search" => "response_status:200",
      "start_at" => "2015-01-13",
      "end_at" => "2015-01-18",
      "interval" => "day",
      "query" => "",
    }, uri.query_values)
  end

  def test_csv_download
    FactoryBot.create_list(:log_item, 5, :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc, :request_method => "OPTIONS")
    FactoryBot.create_list(:log_item, 5, :request_at => 1421413588000, :request_method => "OPTIONS")
    LogItem.gateway.refresh_index!

    admin_login
    visit "/admin/#/stats/logs?search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")

    # Wait for the ajax actions to fetch the graph and tables to both
    # complete, or else the download link seems to be flakey in Capybara.
    assert_text("Download CSV")
    assert_text("OPTIONS")
    refute_selector(".busy-blocker")
    click_link "Download CSV"

    # Downloading files via Capybara generally seems flakey, so add an extra
    # wait.
    Timeout.timeout(Capybara.default_max_wait_time) do
      while(page.response_headers["Content-Type"] != "text/csv")
        sleep(0.1)
      end
    end
    assert_equal(200, page.status_code)
    assert_equal("text/csv", page.response_headers["Content-Type"])
  end

  def test_changing_intervals
    admin_login
    visit "/admin/#/stats/logs?search=&start_at=2015-01-12&end_at=2015-01-13&interval=week"
    refute_selector(".busy-blocker")
    assert_selector("button.active", :text => "Week")
    assert_link("Download CSV", :href => /interval=week/)

    click_button "Day"
    refute_selector("button.active", :text => "Week")
    assert_selector("button.active", :text => "Day")
    assert_link("Download CSV", :href => /interval=day/)

    click_button "Hour"
    refute_selector("button.active", :text => "Day")
    assert_selector("button.active", :text => "Hour")
    assert_link("Download CSV", :href => /interval=hour/)

    click_button "Month"
    refute_selector("button.active", :text => "Hour")
    assert_selector("button.active", :text => "Month")
    assert_link("Download CSV", :href => /interval=month/)

    click_button "Minute"
    refute_selector("button.active", :text => "Month")
    assert_selector("button.active", :text => "Minute")
    assert_link("Download CSV", :href => /interval=minute/)
  end

  def test_date_range_picker
    assert_date_range_picker("/stats/logs")
  end
end
