module TestHelpers
  module Authentication
    def login(member, password='secret')
      @authenticated = member
      request.session[:member_id] = @authenticated.id
    end
    
    def logout
      request.session.delete(:member_id)
    end
    
    def authenticated?
      !request.session[:member_id].blank?
    end
    
    def access_denied?
      response.status.to_i == 403
    end
    
    def login_required?
      response.header['Location'] == new_session_url
    end
  end
end