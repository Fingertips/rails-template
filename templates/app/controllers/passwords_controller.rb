require 'net/smtp'

class PasswordsController < ApplicationController
  allow_access :all
  
  prepend_before_filter :find_member_by_token, :only => [:edit, :update]
  
  def create
    if @member = Member.find_by_email(params[:email])
      @member.generate_reset_password_token!
      Mailer.deliver_reset_password_message(@member, edit_password_url(:id => @member.reset_password_token))
      render :sent
    else
      flash[:error] = "We couldn’t find an account with the email address you entered. Please try again."
      render :new
    end
  rescue Net::SMTPError => e
    smtp_error(e)
    render :new
  end
  
  def update
    @member.password = params[:password]
    if @member.save
      render :reset
    else
      render :edit
    end
  end
  
  private
  
  def find_member_by_token
    unless @member = Member.find_by_reset_password_token(params[:id])
      send_response_document :not_found
    end
  end
  
  def smtp_error(e)
    logger.error "#{e.class} raised while trying to email: #{e.message}

#{e.backtrace.join("
")}"
    flash[:error] = "We're sorry, but your email could not be sent. Please try again later."
  end
end