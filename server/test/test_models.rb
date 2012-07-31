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

describe "Users", "Validation" do
  include Clean::Test::Any

  before do
    @guest_user1 = GuestUser.create :minutes => any_int, :username => 'guest',
                                    :password => any_string, :age => any_int
  end

  after do
    @guest_user1.destroy
  end

  it "must have an unique username, if not anonymous" do
    @guest_user2 = GuestUser.new :minutes => any_int, :username => 'guest',
                                    :password => any_string, :age => any_int
    refute @guest_user2.valid?
  end
end

describe "Clients", "Client-User interaction" do
  include Clean::Test::Any

  before do
    @lib_user = LibraryUser.create :minutes => any_int, :username => any_string,
                                   :age => any_int
    @client = Client.create :ipaddr => any_string, :hwaddr => any_string,
                            :name => any_string
    @guest_user = GuestUser.create :minutes => any_int, :username => any_string,
                                   :password => any_string, :age => any_int
  end

  after do
    @lib_user.destroy
    @guest_user.destroy
    @client.destroy
  end

  it "an user can log on to a client" do
    @lib_user.log_on @client
    @client.user.must_equal @lib_user
  end

  it "an user can log off a client" do
    @lib_user.log_on @client
    assert @client.user == @lib_user
    @lib_user.log_off
    assert @lib_user.client.nil?
    assert @client.user.nil?
    refute @client.occupied?
  end

  it "only one user can log on to client at a time" do
    @lib_user.log_on @client
    assert @client.occupied?
    @guest_user.log_on @client
    refute @client.user == @guest_user
  end

end


describe "Opening Hours" do

  it "must have opening hours or closed-flag for all days in a week" do
    @invalid_h = OpeningHours.new :monday_opens => '10:00', :monday_closes => '19:00'
    refute @invalid_h.valid?
  end

  it "an entry with opening hours for every day must be valid" do
    @valid_h = OpeningHours.new :monday_opens => '10:00', :monday_closes => '19:00',
                                :tuesday_opens => '10:00', :tuesday_closes => '19:00',
                                :wednsday_opens => '10:00', :wednsday_closes => '19:00',
                                :thursday_opens => '10:00', :thursday_closes => '19:00',
                                :friday_opens => '10:00', :friday_closes => '19:00',
                                :saturday_opens => '10:00', :saturday_closes => '19:00',
                                :sunday_opens => '10:00', :sunday_closes => '19:00'
    assert @valid_h.valid?
  end

  it "an entry with closed-flag set for all days must be valid" do
    @valid_h = OpeningHours.new :monday_closed => 1, :tuesday_closed => 1,
      :wednsday_closed => 1, :thursday_closed => 1, :friday_closed => 1,
      :saturday_closed => 1, :sunday_closed => 1
    assert @valid_h.valid?
  end

  it "an entry with a combination of opening hours and closed flag set must be valid" do
    @valid_h = OpeningHours.new :monday_opens => '10:00', :monday_closes => '19:00',
                                :tuesday_opens => '10:00', :tuesday_closes => '19:00',
                                :wednsday_opens => '10:00', :wednsday_closes => '19:00',
                                :thursday_opens => '10:00', :thursday_closes => '19:00',
                                :friday_opens => '10:00', :friday_closes => '19:00',
                                :saturday_closed => 1,
                                :sunday_closed => 1
    assert @valid_h.valid?
  end

  it "cannot have closing hours _before_ opening hours" do
    @invalid_h = OpeningHours.new :monday_opens => '19:00', :monday_closes => '10:00',
                                  :tuesday_opens => '19:00', :tuesday_closes => '10:00',
                                  :wednsday_opens => '19:00', :wednsday_closes => '10:00',
                                  :thursday_opens => '19:00', :thursday_closes => '10:00',
                                  :friday_opens => '19:00', :friday_closes => '10:00',
                                  :saturday_closed => 1,
                                  :sunday_closed => 1
    refute @invalid_h.valid?
  end
end
