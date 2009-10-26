require File.expand_path('../../../test_helper', __FILE__)

describe "Member, concerning authentication" do
  it "should hash passwords" do
    Member.hash_password('secret').should == 'e5e9fa1ba31ecd1ae84f75caaa474f3a663f05f4'
  end
  
  it "should authenticate users with correct credentials" do
    member = Member.authenticate(:email => 'adrian@example.com', :password => 'secret')
    member.errors.should.be.empty
  end
  
  it "should not authenticate users with incorrect credentials" do
    member = Member.authenticate(:email => 'adrian@example.com', :password => 'incorrect')
    member.errors.should.not.be.empty
    member.errors.on(:base).should.not.be.blank
  end
  
  it "should not authenticate non-existant users" do
    member = Member.authenticate(:email => 'unknown@example.com', :password => 'incorrect')
    member.errors.should.not.be.empty
    member.errors.on(:base).should.not.be.blank
  end
end

describe "A member, concerning authentication" do
  before do
    @member = members(:adrian)
  end
  
  it "should require a password" do
    @member.password = ''
    @member.should.not.be.valid
    @member.errors.on(:password).should.not.be.blank
    
    @member.hashed_password = Member.hash_password('')
    @member.should.not.be.valid
    @member.errors.on(:password).should.not.be.blank
  end
  
  it "should automatically hash passwords" do
    @member.password = 'secret'
    @member.hashed_password.should == Member.hash_password('secret')
    
    @member.password = 'not so secret'
    @member.hashed_password.should == Member.hash_password('not so secret')
  end
  
  it "should respond to password" do
    @member.should.respond_to(:password)
  end
  
  it "should generate a new reset password token" do
    token = Token.generate
    Token.stubs(:generate).returns(token)
    
    @member.generate_reset_password_token!
    @member.reload.reset_password_token.should == token
  end
  
  %w{ hashed_password role reset_password_token }.each do |attribute|
    it "should not allow access to `#{attribute}'" do
      before = @member.send(attribute)
      @member.update_attributes(attribute => '[updated]')
      @member.reload.send(attribute).should == before
    end
  end
  
  it "should allow access to password and verify password" do
    @member.update_attributes(:password => 'new', :verify_password => 'new')
    @member.reload.hashed_password.should == Member.hash_password('new')
  end
end