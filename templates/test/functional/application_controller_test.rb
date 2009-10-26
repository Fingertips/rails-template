require File.expand_path('../../test_helper', __FILE__)

class TestApplicationsController < ApplicationController
  allow_access :admin, :only => :private_action
  allow_access :all, :except => :private_action
  
  def private_action
    render :nothing => true
  end
  
  def private_action_with_flash
    flash[:notice] = 'Message'
    render :nothing => true
  end
  
  def public_action
    render :nothing => true
  end
  
  def action_with_layout
    render :inline => '', :layout => 'application'
  end
  
  def action_with_respond_block
    respond_to do |format|
      format.html { render :text => 'HTML' }
      format.jpg { render :text => 'JPG'}
    end
  end
end

ActionController::Routing::Routes.draw do |map|
  map.resource :test_application, :member => {
    :private_action => :get,
    :private_action_with_flash => :get,
    :public_action => :get,
    :action_with_layout => :get,
    :action_with_respond_block => :get
  }
end

describe TestApplicationsController do
  it "should find the currently logged in member" do
    login members(:adrian)
    get :public_action
    assigns(:authenticated).should == members(:adrian)
  end
  
  it "should not find currently logged in member when no-one is logged in" do
    get :public_action
    assigns(:authenticated).should.be.blank
  end
  
  it "should log a member in" do
    should.not.be.authenticated
    @controller.send(:login, members(:adrian))
    should.be.authenticated
  end
  
  it "should log a member out" do
    @controller.send(:login, members(:adrian))
    should.be.authenticated
    @controller.send(:logout)
    should.not.be.authenticated
  end
  
  it "should respond with HTML before JPG" do
    request.env['HTTP_ACCEPT'] = "*/*"
    get :action_with_respond_block
    response.body.should == 'HTML'
  end
  
  it "should respond with HTML before JPG, even with IE" do
    request.env["HTTP_USER_AGENT"] = 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0; Win64; x64)'
    request.env['HTTP_ACCEPT'] = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, application/xaml+xml, application/vnd.ms-xpsdocument, application/x-ms-xbap, application/x-ms-application, application/x-shockwave-flash, application/x-silverlight, */*"
    get :action_with_respond_block
    response.body.should == 'HTML'
  end
end

describe TestApplicationsController, "when dealing with pages that need authorization" do
  it "should allow the user to authorize" do
    get :private_action
    should.redirect_to new_session_url
  end
  
  it "should keep the flash around when access was refused" do
    get :private_action_with_flash
    flash[:notice].should == 'Message'
  end
  
  it "should have stored the url to return the user to after authentication" do
   get :private_action
   controller.after_authentication[:redirect_to].should == controller.url_for(:action => :private_action)
  end
  
  it "should show a forbidden page when access was refused" do
    controller.stubs(:find_authenticated)
    controller.send(:instance_variable_set, "@authenticated", stub(:id => 1, :role => 'member'))
    
    get :private_action
    status.should.be :forbidden
  end
end