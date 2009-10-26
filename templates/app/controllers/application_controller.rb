class ApplicationController < ActionController::Base
  helper :all
  protect_from_forgery
  filter_parameter_logging :password
  before_filter :find_authenticated, :block_access, :set_actionmailer_host
  # report_errors_to 'http://forestwatcher.example.com/test_app', :username => 'forestwatcher', :password => 'secret'
  
  protected
  
  # Responds with a http status code and an error document
  def send_response_document(status)
    format = (request.format === [Mime::XML, Mime::JSON]) ? request.format : Mime::HTML
    status = interpret_status(status)
    send_file "#{RAILS_ROOT}/public/#{status.to_i}.#{format.to_sym}",
      :status => status,
      :type => "#{format}; charset=utf-8",
      :disposition => 'inline',
      :stream => false
  end
  
  def find_authenticated
    @authenticated = Member.find_by_id(request.session[:member_id]) unless request.session[:member_id].blank?
  end
  
  # Handles interaction when the client may not access the current resource
  def access_forbidden
    if !@authenticated.nil?
      send_response_document :forbidden
    else
      flash.keep
      authentication_needed!
    end
  end
  
  def when_authentication_needed
    redirect_to new_session_url
  end
  
  # Set the hostname of the server on ActionMailer
  def set_actionmailer_host
    ActionMailer::Base.default_url_options[:host] = request.host_with_port
  end
  
  def login(member)
    request.session[:member_id] = member.id
  end
  
  def logout
    request.session.delete(:member_id)
  end
end