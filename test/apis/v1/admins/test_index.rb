require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Admin.delete_all
  end

  include ApiUmbrellaSharedTests::DataTablesApi

  def test_filled_attributes_response_fields
    record = FactoryBot.create(:filled_attributes_admin)

    response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => record.id },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_data_tables_root_fields(data)
    assert_equal(1, data.fetch("data").length)

    record_data = data.fetch("data").first
    assert_base_record_fields(record_data)

    assert_equal("2017-01-01T00:00:00Z", record_data.fetch("created_at"))
    assert_match_uuid(record_data.fetch("created_by"))
    assert_equal(record.created_by, record_data.fetch("created_by"))
    assert_equal("2017-01-05T00:00:00Z", record_data.fetch("current_sign_in_at"))
    assert_equal("10.11.2.3", record_data.fetch("current_sign_in_ip"))
    assert_equal("Provider1", record_data.fetch("current_sign_in_provider"))
    assert_match(/@example.com/, record_data.fetch("email"))
    assert_equal(3, record_data.fetch("failed_attempts"))
    assert_equal(1, record_data.fetch("group_ids").length)
    assert_match_uuid(record_data.fetch("group_ids").first)
    assert_equal(record.groups.first.id, record_data.fetch("group_ids").first)
    assert_equal(2, record_data.fetch("group_names").length)
    assert_equal([
      "ExampleFilledGroup",
      "Superuser",
    ], record_data.fetch("group_names").sort)
    assert_equal("2017-01-06T00:00:00Z", record_data.fetch("last_sign_in_at"))
    assert_equal("10.11.2.4", record_data.fetch("last_sign_in_ip"))
    assert_equal("Provider2", record_data.fetch("last_sign_in_provider"))
    assert_equal("2017-01-07T00:00:00Z", record_data.fetch("locked_at"))
    assert_equal("Name", record_data.fetch("name"))
    assert_equal("Notes", record_data.fetch("notes"))
    assert_equal("2017-01-04T00:00:00Z", record_data.fetch("remember_created_at"))
    assert_equal("2017-01-03T00:00:00Z", record_data.fetch("reset_password_sent_at"))
    assert_equal(10, record_data.fetch("sign_in_count"))
    assert_equal(true, record_data.fetch("superuser"))
    assert_equal("2017-01-02T00:00:00Z", record_data.fetch("updated_at"))
    assert_match_uuid(record_data.fetch("updated_by"))
    assert_equal(record.updated_by, record_data.fetch("updated_by"))
    assert_match(/@example.com/, record_data.fetch("username"))
  end

  def test_empty_attributes_response_fields
    record = FactoryBot.create(:empty_attributes_admin)

    response = Typhoeus.get(data_tables_api_url, http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => record.id },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_data_tables_root_fields(data)
    assert_equal(1, data.fetch("data").length)

    record_data = data.fetch("data").first
    assert_base_record_fields(record_data)

    assert_nil(record_data.fetch("created_by"))
    assert_nil(record_data.fetch("updated_by"))
    assert_equal([], record_data.fetch("group_ids"))
    assert_equal(["Superuser"], record_data.fetch("group_names"))
  end

  def test_search_name
    assert_data_tables_search(:name, "NameSearchTest", "amesearcht")
  end

  def test_search_email
    assert_data_tables_search(:email, "EmailSearchTest@example.com", "mailsearchtest@exampl")
  end

  def test_search_username
    assert_data_tables_search(:username, "usernametest", "ernametes")
  end

  def test_order_email
    assert_data_tables_order(:email, ["a@example.com", "b@example.com"])
  end

  def test_order_current_sign_in_at
    assert_data_tables_order(:current_sign_in_at, [Time.utc(2017, 1, 1), Time.utc(2017, 1, 2)])
  end

  def test_order_created_at
    assert_data_tables_order(:created_at, [Time.utc(2017, 1, 1), Time.utc(2017, 1, 2)])
  end

  private

  def data_tables_api_url
    "https://127.0.0.1:9081/api-umbrella/v1/admins.json"
  end

  def data_tables_factory_name
    :admin
  end

  def data_tables_record_count
    Admin.where(:deleted_at => nil).count
  end

  def assert_base_record_fields(record_data)
    assert_equal([
      "created_at",
      "created_by",
      "current_sign_in_at",
      "current_sign_in_ip",
      "current_sign_in_provider",
      "deleted_at",
      "email",
      "failed_attempts",
      "group_ids",
      "group_names",
      "id",
      "last_sign_in_at",
      "last_sign_in_ip",
      "last_sign_in_provider",
      "locked_at",
      "name",
      "notes",
      "remember_created_at",
      "reset_password_sent_at",
      "sign_in_count",
      "superuser",
      "updated_at",
      "updated_by",
      "username",
      "version",
    ].sort, record_data.keys.sort)
    assert_match_iso8601(record_data.fetch("created_at"))
    assert_nil(record_data.fetch("deleted_at"))
    assert_kind_of(String, record_data.fetch("email"))
    assert_kind_of(Integer, record_data.fetch("failed_attempts"))
    assert_kind_of(Array, record_data.fetch("group_ids"))
    assert_kind_of(Array, record_data.fetch("group_names"))
    assert_match_uuid(record_data.fetch("id"))
    assert_kind_of(Integer, record_data.fetch("sign_in_count"))
    assert_includes([true, false], record_data.fetch("superuser"))
    assert_match_iso8601(record_data.fetch("updated_at"))
    assert_kind_of(String, record_data.fetch("username"))
    assert_kind_of(Integer, record_data.fetch("version"))
  end
end
