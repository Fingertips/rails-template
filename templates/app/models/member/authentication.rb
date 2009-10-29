require 'digest/sha1'

class Member
  attr_accessible :password, :verify_password
  
  def generate_reset_password_token!
    update_attribute :reset_password_token, Token.generate
  end
  
  attr_reader :password
  def password=(password)
    self.hashed_password = self.class.hash_password(password)
  end
  
  def verify_password=(password)
    @verify_password = self.class.hash_password(password)
  end
  
  def self.hash_password(password)
    ::Digest::SHA1.hexdigest(password)
  end
  
  # Authenticates credentials. Takes a hash with a :email and :password,
  # returns an instance of Member. The Member has errors on base when
  # the user isn't authenticated.
  def self.authenticate(params={})
    unless member = find_by_email_and_hashed_password(params[:email], hash_password(params[:password]))
      member = Member.new(params.slice(:email, :password))
      member.errors.add_to_base("The credentials you entered are invalid. Please try again.")
      member
    else
      member
    end
  end
  
  private
  
  def password_is_not_blank
    if hashed_password == self.class.hash_password('')
      errors.add(:password, "can't be blank")
    end
  end
  
  validate :password_is_not_blank
end