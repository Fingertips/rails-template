require File.expand_path('../../test_helper', __FILE__)

describe "Model that includes ActiveRecord::Ext" do
  it "should have a named scope to order" do
    Member.order('email').should.equal_set Member.all
    Member.order('email').map(&:email).should == Member.all.map(&:email).sort
    Member.order('email', :desc).map(&:email).should == Member.all.map(&:email).sort.reverse
  end
  
  it "should have a named scope to limit" do
    Member.limit(3).should.equal_set Member.all(:limit => 3)
  end
end