require "helpers/active_record"
require "clean_test/test_case"
require "./models"

class OrganizationTest < Clean::Test::TestCase
  test_that "mysql schema is created" do
    Given { @org = Organization.create(:name => "Deichman") }
    When { }
    Then { assert_equal "Deichman", @org.name }

  end
end