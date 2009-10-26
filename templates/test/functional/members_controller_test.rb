require File.expand_path('../../test_helper', __FILE__)

describe "On the", MembersController, "a visitor" do
  it "should see a form for a new member" do
    get :new
    status.should.be :ok
    template.should.be 'members/new'
    assert_select 'form'
  end
  
  it "should create a new member" do
    lambda {
      post :create, :member => valid_params
    }.should.differ('Member.count', +1)
    assigns(:member).email.should == valid_params[:email]
    assigns(:member).hashed_password.should == Member.hash_password(valid_params[:password])
    should.redirect_to root_url
    should.be.authenticated
  end
  
  it "should show validation errors after a failed create" do
    post :create, :member => valid_params.merge(:email => '')
    status.should.be :ok
    template.should.be 'members/new'
    assert_select 'div.errorExplanation'
    assert_select 'form'
    should.not.be.authenticated
  end
  
  it "should see a profile" do
    get :show, :id => members(:adrian)
    assigns(:member).should == members(:adrian)
    status.should.be :success
    template.should.be 'members/show'
  end
  
  should.require_login.get :edit, :id => members(:adrian)
  should.require_login.put :update, :id => members(:adrian)
  should.require_login.delete :destroy, :id => members(:adrian)
  
  private
  
  def valid_params
    { :email => 'jurgen@example.com', :password => 'so secret', :verify_password => 'so secret' }
  end
end

describe "On the", MembersController, "a member" do
  before do
    login members(:adrian)
  end
  
  it "should see an edit form" do
    get :edit, :id => @authenticated.to_param
    
    assert_select 'form'
    assigns(:member).should == @authenticated
    status.should.be :success
    template.should.be 'members/edit'
  end
  
  it "should be able to update his profile" do
    put :update, :id => @authenticated.to_param, :member => { :email => 'sir.adrian@example.com' }
    
    @authenticated.reload.email.should == 'sir.adrian@example.com'
    should.redirect_to member_url(@authenticated)
  end
  
  should.disallow.put :update, :id => members(:kelly)
  should.disallow.delete :destroy, :id => members(:kelly)
end