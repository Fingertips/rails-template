require File.expand_path('../../../test_helper', __FILE__)

describe ApplicationHelper, "concerning navigation" do
  attr_accessor :request
  before do
    @request    = stub(:request_uri => '/members')
    @controller = stub(:request => @request)
  end
  
  it "should generate a navigation link" do
    assert_dom_equal('<a href="/passwords/new">Reset password</a>',    nav_link_to('Reset password', '/passwords/new'))
    assert_dom_equal('<a href="/members" class="current">Members</a>', nav_link_to('Members', '/members'))
  end
  
  it "should generate a navigation item" do
    assert_dom_equal('<li><a href="/passwords/new">Reset password</a></li>', nav_item('Reset password', '/passwords/new'))
  end
  
  it "should generate a navigation item with extra options" do
    assert_dom_equal('<li class="first"><a href="/passwords/new">Reset password</a></li>', nav_item('Reset password', '/passwords/new', :class => 'first'))
  end
  
  it "should generate a navigation item when the current page is equal to the navigation item" do
    assert_dom_equal('<li class="current"><a href="/members">Members</a></li>', nav_item('Members', '/members'))
  end
  
  it "should generate a navigation item when the current page is equal to the navigation item with extra options" do
    assert_dom_equal('<li class="first current"><a href="/members">Members</a></li>', nav_item('Members', '/members', :class => 'first'))
  end
  
  it "should generate a navigation item when the current page is more specific than the navigation item" do
    @request = stub(:request_uri => '/members/12')
    assert_dom_equal('<li class="current"><a href="/members">Members</a></li>', nav_item('Members', '/members'))
  end
  
  it "should generate a shallow navigation item that doesn't become current when a subpage is viewed" do
    assert_dom_equal('<li><a href="/">Home</a></li>', nav_item('Home', '/', :shallow => true))
  end
  
  it "should generate a shallow navigation item that becomes current when the page it links to is viewed" do
    @request = stub(:request_uri => '/')
    assert_dom_equal('<li class="current"><a href="/">Home</a></li>', nav_item('Home', '/', :shallow => true))
  end
end