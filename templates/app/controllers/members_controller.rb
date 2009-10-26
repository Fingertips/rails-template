class MembersController < ApplicationController
  allow_access(:authenticated) { @authenticated.to_param == params[:id] }
  allow_access :all, :only => [:new, :create, :show]
  
  before_filter :find_member, :only => [:show, :edit, :update]
  
  def new
    @member = Member.new
  end
  
  def create
    @member = Member.new(params[:member])
    
    if @member.save
      login(@member)
      redirect_to root_url
    else
      render :new
    end
  end
  
  def update
    @member.update_attributes(params[:member])
    redirect_to member_url(@member)
  end
  
  private
  
  def find_member
    @member = Member.find(params[:id])
  end
end