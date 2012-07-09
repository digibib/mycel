# encoding: UTF-8 
require "helpers/active_record"
require "clean_test/test_case"
require "./models"

class OrganizationTest < Clean::Test::TestCase
  def setup
    branch1 = Branch.create(:name => "Grünerløkka")
    branch2 = Branch.create(:name => "Hovedbiblioteket")
    dept1 = Department.create(:name => "Voksenavdeligen")
    dept2 = Department.create(:name => "Unge Deichman")
    dept3 = Department.create(:name => "Serieteket")
    branch1.departments << dept3
    branch2.departments << [dept1, dept2]
    @org = Organization.create(:name => any_string)
    @org.branches << [branch1, branch2]
  end

  test_that "branches belongs to organization" do
    assert_equal 2, @org.branches.size
  end

  test_that "departments belongs to branches" do
    assert_equal 2, @org.branches.find_by_name("Hovedbiblioteket").departments.size
  end

  test_that "organization can access departments (throught branches)" do
    assert_equal 3, @org.departments.size
  end

  def teardown
    @org.destroy
  end
end

class HierarchyTest < Clean::Test::TestCase
  def setup
    @org = Organization.create(:name => any_string)
    client = Client.create(:name => any_string, :hwaddr => any_string, :ipaddr => any_string)
    branch = Branch.create(:name => any_string, :homepage => "www.nrk.no")
    dept = Department.create(:name => any_string)
    dept.clients << client
    branch.departments << dept
    @org.branches << branch
  end

  test_that "if homepage not set in client, fetches it from dept or branch" do
    assert_equal "www.nrk.no", Client.find(1).homepage
  end

  def teardown
    @org.destroy
  end
end