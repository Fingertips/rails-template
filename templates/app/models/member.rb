class Member < ActiveRecord::Base
  embrace :authentication
  
  attr_accessible :email
  
  private
  
  validates_uniqueness_of :email
  validates_email :email
end