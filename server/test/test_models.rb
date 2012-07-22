# encoding: UTF-8
require "helpers/active_record"
require "minitest/autorun"
require "clean_test/any"
require "./models"

describe "Users" do
  include Clean::Test::Any

  before do
    @lib_user = LibraryUser.create :minutes => any_int, :username => any_string,
                                   :age => any_int
    @guest_user = GuestUser.create :minutes => any_int, :username => any_string,
                                   :password => any_string, :age => any_int
    @anon_user = AnonymousUser.create :minutes => any_int
  end

  after do
    @lib_user.destroy
    @guest_user.destroy
    @anon_user.destroy
  end

  it "can be a Library patron" do
    @lib_user.must_be_kind_of(User)
  end

  it "can be a guest user" do
    @guest_user.must_be_kind_of(User)
  end

  it "can be an anonymous user" do
    @anon_user.must_be_kind_of(User)
  end

  it "must include all users, regarldess of type" do
    User.all.count.must_equal 3
  end

end
