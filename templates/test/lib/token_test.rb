require File.expand_path('../../test_helper', __FILE__)

describe "Token" do
  it "should generate a token" do
    Token.generate.should.not.be.blank
  end
  
  it "should not generate the same token twice in quick succession" do
    Token.generate.should.not == Token.generate
  end
  
  it "should generate tokens of specific lengths" do
    Token.generate(3).length.should == 3
    Token.generate(40).length.should == 40
    Token.generate(61).length.should == 61
  end
end