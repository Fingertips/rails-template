require File.expand_path('../../test_helper', __FILE__)

describe "On the", PasswordsController, "a visitor" do
  before do
    @member = members(:adrian)
  end
  
  it "should see a new form to reset his password" do
    get :new
    status.should.be :success
    template.should.be 'passwords/new'
    assert_select 'form'
  end
  
  it "should generate a password reset token and send it via email" do
    @member.update_attribute(:reset_password_token, nil)
    
    assert_emails(1) do
      post :create, :email => @member.email
    end
    
    assigns(:member).should == @member
    @member.reload.reset_password_token.should.not.be.blank
    
    email = ActionMailer::Base.deliveries.last
    email.body.should.include edit_password_url(:id => @member.reset_password_token)
    
    status.should.be :success
    template.should.be 'passwords/sent'
  end
  
  it "should see an error if no member can be found for a given email address" do
    assert_emails(0) do
      post :create, :email => "joe.the.plumber@example.com"
    end
    
    status.should.be :ok
    template.should.be 'passwords/new'
    flash[:error].should.not.be.blank
  end
  
  it "should see a warning if an SMTP error occurred" do
    Mailer.stubs(:deliver_reset_password_message).raises Net::SMTPFatalError
    post :create, :email => @member.email
    
    status.should.be :ok
    template.should.be 'passwords/new'
    flash[:error].should.not.be.blank
  end
  
  it "should see an edit form for his password" do
    @member.generate_reset_password_token!
    get :edit, :id => @member.reset_password_token
    
    status.should.be :success
    assigns(:member).should == @member
    template.should.be 'passwords/edit'
    assert_select 'form'
  end
  
  it "should not see an edit form if no member is found for the given token" do
    get :edit, :id => "doesnotexist"
    
    status.should.be :not_found
    assigns(:member).should.be nil
  end
  
  it "should be able to update his password" do
    @member.generate_reset_password_token!
    put :update, :id => @member.reset_password_token, :password => "newpass"
    
    Member.authenticate(:email => @member.email, :password => "newpass").should == @member
    status.should.be :success
    template.should.be 'passwords/reset'
  end
  
  it "should see an error if the password is empty" do
    @member.generate_reset_password_token!
    before = @member.hashed_password
    
    put :update, :id => @member.reset_password_token, :password => ""
    
    @member.reload.hashed_password.should == before
    status.should.be :success
    template.should.be 'passwords/edit'
    assert_select "div.errorExplanation", :text => "The password can’t be blank."
  end
  
  it "should not be allowed to update a password with an incorrect token" do
    put :update, :id => "doesnotexist", :password => "newpass"
    
    status.should.be :not_found
    assigns(:member).should.be nil
  end
end