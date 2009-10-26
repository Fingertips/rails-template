class SessionsController < ApplicationController
  allow_access :all
  
  def new
    still_authentication_needed!
    @unauthenticated = Member.new
  end
  
  def create
    @unauthenticated = Member.authenticate(params[:member])
    if @unauthenticated.errors.blank?
      login(@unauthenticated)
      finish_authentication_needed! || redirect_to(root_url)
    else
      still_authentication_needed!
      flash[:login_error] = @unauthenticated.errors.on(:base)
      render :new
    end
  end
  
  def clear
    logout
    flash[:notice] = "You are now logged out."
    redirect_to root_url
  end
end