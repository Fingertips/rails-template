# TODO: For client apps we want to add some arg (ENV) to choose between a OSS
# git project and a closed svn one. The svn version should install gems instead
# of creating checkouts of the git libs in vendor/plugins.

require 'fileutils'

class Rails::TemplateRunner
  def name
    File.basename(root)
  end
  
  def yes?(question)
    answer = ask(question).downcase
    answer == 'y' || answer == 'yes' || answer.empty?
  end
end

def test_cache(dir)
  if ENV['TEST_TEMPLATE'] && File.exist?(File.join('../vendor_cache', dir))
    puts "[!] Using #{dir} cache..."
    FileUtils.cp_r "../vendor_cache/#{dir}", "vendor"
  else
    yield
    if ENV['TEST_TEMPLATE']
      puts "[!] Creating #{dir} cache..."
      FileUtils.mkdir_p "../vendor_cache"
      FileUtils.cp_r "vendor/#{dir}", "../vendor_cache"
    end
  end
end

####
#
# Skeleton template
#

# Rails

test_cache 'rails' do
  # On 2.3.4 the git command is broken as it only executes in_root...
  inside 'vendor' do
    Git.run 'clone git://github.com/Fingertips/rails.git'
    run 'cd rails && git remote add rails git://github.com/rails/rails.git'
  end
end

# Plugins

test_cache 'plugins' do
  plugin 'authentication-needed-san', :git => 'git://github.com/Fingertips/authentication-needed-san.git'
  plugin 'authorization-san',         :git => 'git://github.com/Fingertips/authorization-san.git'
  plugin 'generator-san',             :git => 'git://github.com/Fingertips/generator-san.git'
  plugin 'peiji-san',                 :git => 'git://github.com/Fingertips/peiji-san.git'
  plugin 'on-test-spec',              :git => 'git://github.com/Fingertips/on-test-spec.git'
end

# Gems

environment "gem 'test-spec', :version => '~> 0.10.0', :lib => 'test/spec'", :env => :test
rake 'gems:install', :env => :test, :sudo => true

# Rake

file 'Rakefile',
%{require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'tasks/rails'

namespace :test do
  desc "Run the javascript tests in test/javascripts"
  task :javascripts do
    sh "jstest \#{Dir['test/javascripts/*.html'].join(' ')}"
  end
  
  Rake::TestTask.new('lib') do |t|
    t.test_files = FileList['test/lib/**/*_test.rb']
    t.verbose = true
  end
end

task :test do
  Rake::Task['test:lib'].invoke
  Rake::Task['test:javascripts'].invoke
end}

# Database

if yes? 'Use MySQL instead of SQLite? [Y/n]'
  file 'config/database.yml',
%{development:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{name}_development
  pool: 5
test:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{name}_test
  pool: 5
production:
  adapter: mysql
  encoding: utf8
  reconnect: false
  database: #{name}_production
  pool: 5}
end

# Test

file 'test/test_helper.rb',
%{ENV["RAILS_ENV"] = "test"

require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

require 'mocha'
require 'test/spec'
require 'test/spec/rails'
require 'test/spec/rails/macros'
require 'test/spec/share'

# require 'test/spec/add_allow_switch'
# Net::HTTP.add_allow_switch :start

class ActiveSupport::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
  fixtures :all
  
  $:.unshift(File.expand_path('../', __FILE__))
  
  require 'ext/authentication'
  include TestHelpers::Authentication
  
  require 'ext/time'
  include TestHelpers::Time
  
  require 'ext/file_fixtures'
  include TestHelpers::FileFixtures
end

ActionMailer::Base.default_url_options[:host] = 'test.host'}

inside 'test/ext' do
  file 'test/ext/authentication.rb',
%{module TestHelpers
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
end}
  
  file 'test/ext/file_fixtures.rb',
%{module TestHelpers
  module FileFixtures
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
      ActionController::TestUploadedFile.new("\#{fixture_path}\#{path}", mime_type, binary)
    end
  end
end}
  
  file 'test/ext/time.rb',
%{module TestHelpers
  module Time
    def freeze_time!(time = ::Time.parse('6/1/2009'))
      ::Time.stubs(:now).returns(time)
      time
    end
  end
end}
end

# Lib

initializer 'core_ext.rb',
%{require 'active_record_ext'

ActiveRecord::Base.send(:extend, ActiveRecord::Ext)
ActiveRecord::Base.send(:include, ActiveRecord::BasicScopes)}

inside 'lib' do
  file 'lib/active_record_ext.rb',
%{module ActiveRecord
  module Ext
    # Loads various parts of a class definition, a simple way to separate large classes.
    #
    #   class Member
    #     embrace :authentication
    #   end
    def embrace(*parts)
      parts.each do |part|
        require_dependency "\#{name.downcase}/\#{part}"
      end
    end
  end
  
  module BasicScopes
    def self.included(base)
      base.named_scope(:order, Proc.new do |attribute, direction|
        order = "\#{attribute}"
        order << " \#{direction.to_s.upcase}" unless direction.blank?
        { :order => order }
      end)
      
      base.named_scope :limit, Proc.new { |limit| { :limit => limit } }
    end
  end
end}
end

inside 'test/lib' do
  file 'test/lib/active_record_ext_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

describe "Model that includes ActiveRecord::Ext" do
  it "should have a named scope to order" do
    Member.order('email').should.equal_set Member.all
    Member.order('email').map(&:email).should == Member.all.map(&:email).sort
    Member.order('email', :desc).map(&:email).should == Member.all.map(&:email).sort.reverse
  end
  
  it "should have a named scope to limit" do
    Member.limit(3).should.equal_set Member.all(:limit => 3)
  end
end}
end

file 'lib/token.rb',
%{module Token
  DEFAULT_LENGTH = 8
  
  def self.generate(requested_length=DEFAULT_LENGTH)
    length = requested_length.odd? ? requested_length + 1 : requested_length
    token = (1..length/2).map { |i| (1..2).map { (i.odd? ? ('a'..'z') : ('0'..'9')).to_a.rand }.join }.join
    token[0...requested_length]
  end
end}

file 'test/lib/token_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

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
end}

# Concerns

# TODO: This should probably move to a plugin.
inside 'app/concerns' do
  file 'app/concerns/nested_resource_methods.rb',
%{module Concerns
  module NestedResourceMethods
    def self.included(klass)
      klass.extend ClassMethods
    end
    
    module ClassMethods
      def find_parent_resource(options = {})
        before_filter :find_parent_resource, options
      end
    end
    
    protected
    
    def nested?
      !parent_resource_params.empty?
    end
    
    def parent_resource_params
      @parent_resource_params ||=
        if key = params.keys.find { |k| k =~ /^(\\w+)_id$/ }
          { :param => key, :id => params[key], :name => $1, :class_name => $1.classify, :class => $1.classify.constantize }
        else
          {}
        end
    end
    
    def find_parent_resource
      if @parent_resource.nil? && nested? && @parent_resource = parent_resource_params[:class].find(parent_resource_params[:id])
        instance_variable_set("@\#{parent_resource_params[:name]}", @parent_resource)
      end
      @parent_resource
    end
  end
end}
end

inside 'test/unit/concerns' do
  file 'test/unit/concerns/nested_resource_methods_test.rb',
%{require File.expand_path('../../../test_helper', __FILE__)

class NestedResourceTestController
  include Concerns::NestedResourceMethods
  public :nested?, :parent_resource_params, :find_parent_resource
  
  attr_reader :params
  def params=(params)
    @params = params.with_indifferent_access
  end
end

+lass CamelCaseTest
end

describe "NestedResourceMethods, at the class level" do
  it "should define a before_filter which finds the parent resource" do
    NestedResourceTestController.expects(:before_filter).with(:find_parent_resource, {})
    NestedResourceTestController.find_parent_resource
  end
  
  it "should forward options to the before_filter" do
    NestedResourceTestController.expects(:before_filter).with(:find_parent_resource, :only => :index)
    NestedResourceTestController.find_parent_resource :only => :index
  end
end

describe "NestedResourceMethods" do
  attr_accessor :controller
  
  before do
    @controller = NestedResourceTestController.new
    @member = members(:adrian)
  end
  
  it "should know if it's not a nested request" do
    controller.params = {}
    controller.should.not.be.nested
  end
  
  it "should know if this is a nested request" do
    controller.params = { :member_id => 12 }
    controller.should.be.nested
  end
  
  it "should know the parent resource params" do
    controller.params = { :member_id => 12, :id => 34 }
    controller.parent_resource_params.should == { :name => 'member', :class => Member, :param => 'member_id', :class_name => 'Member', :id => 12 }
  end
  
  it "should know the parent resource params for camelcased classes" do
    controller.params = { :camel_case_test_id => 12, :id => 34 }
    controller.parent_resource_params.should == { :name => 'camel_case_test', :class => CamelCaseTest, :param => 'camel_case_test_id', :class_name => 'CamelCaseTest', :id => 12 }
  end
  
  it "should have cached the parent_resource_params" do
    controller.params = { :member_id => 12, :id => 34 }
    params = controller.parent_resource_params
    controller.parent_resource_params.should.be params
  end
  
  it "should find the nested resource" do
    controller.params = { :member_id => @member.to_param }
    controller.find_parent_resource
    assigns(:parent_resource).should == @member
  end
  
  it "should also set an instance variable named after the parent resource" do
    controller.params = { :member_id => @member.to_param }
    controller.find_parent_resource.should == @member
    assigns(:member).should == @member
  end
  
  it "should return nil if the resource isn't nested" do
    controller.params = {}
    controller.find_parent_resource.should.be nil
    assigns(:parent_resource).should.be nil
  end
  
  private
  
  def assigns(name)
    controller.instance_variable_get("@\#{name}")
  end
end}
end

####
#
# Application template
#

initializer 'application',
%{SYSTEM_EMAIL_ADDRESS = '#{name.camelize} Support <support@example.com>'
EMAIL_REGEXP         = /^([^@\\s]+)@((?:[-a-z0-9]+\\.)+[a-z]{2,})$/i}

# Routes

# For some reason these routes are generated in the reversed order...
route 'map.root :controller => "members", :action => "new"'
route 'map.resource  :session, :collection => { :clear => :get }'
route 'map.resources :passwords'
route 'map.resources :members'

# Models

generate :model_san, 'member role:string email:string hashed_password:string reset_password_token:string'

file 'app/models/member.rb',
%{class Member < ActiveRecord::Base
  embrace :authentication
  
  attr_accessible :email
  
  private
  
  validates_uniqueness_of :email
  validates_format_of :email, :with => EMAIL_REGEXP
end}

file 'test/unit/member_test.rb',
%{describe Member, "concerning validations" do
  before do
    @member = Member.new
  end
  
  it "should require an email" do
    @member.email = ''
    @member.should.not.be.valid
    @member.errors.on(:email).should.not.be.blank
  end
  
  it "should require a valid email" do
    @member.email = 'invalid'
    @member.should.not.be.valid
    @member.errors.on(:email).should.not.be.blank
  end
  
  it "should require a unique email" do
    @member.email = members(:adrian).email
    @member.should.not.be.valid
    @member.errors.on(:email).should.not.be.blank
  end
end

describe 'A', Member do
  it "should allow access to email" do
    members(:adrian).update_attributes(:email => 'new@example.com')
    members(:adrian).reload.email.should == 'new@example.com'
  end
end}

inside 'app/models/member' do
  file 'app/models/member/authentication.rb',
%{require 'digest/sha1'

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
  
  # Authenticates credentials. Takes a hash with a :email and :password, returns an instance of Member.
  # The Member has errors on base when the user isn't authenticated.
  def self.authenticate(params={})
    unless member = find_by_email_and_hashed_password(params[:email], hash_password(params[:password]))
      member = Member.new
      member.errors.add_to_base("The username and/or email you entered is invalid. Please try again.")
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
end}
end

inside 'test/unit/member' do
  file 'test/unit/member/authentication_test.rb',
%{require File.expand_path('../../../test_helper', __FILE__)

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
    it "should not allow access to `\#{attribute}'" do
      before = @member.send(attribute)
      @member.update_attributes(attribute => '[updated]')
      @member.reload.send(attribute).should == before
    end
  end
  
  it "should allow access to password and verify password" do
    @member.update_attributes(:password => 'new', :verify_password => 'new')
    @member.reload.hashed_password.should == Member.hash_password('new')
  end
end}
end

file 'test/fixtures/members.yml',
%{adrian:
  hashed_password: <%= Member.hash_password('secret') %>
  email: adrian@example.com
  role: member
kelly:
  hashed_password: <%= Member.hash_password('secret') %>
  email: kelly@example.com
  role: member}

file 'app/models/mailer.rb',
%{class Mailer < ActionMailer::Base
  def reset_password_message(member, url)
    recipients member.email
    from       SYSTEM_EMAIL_ADDRESS
    subject    "[#{name.camelize}] Confirm password reset"
    body       :member => member, :url => url
  end
end}

file 'test/unit/mailer_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

describe "Mailer", ActionMailer::TestCase do
  it "should render a reset password message" do
    member = members(:adrian)
    member.generate_reset_password_token!
    url = "http://test.host/password/\#{member.reset_password_token}/edit"
    
    email = Mailer.create_reset_password_message(member, url)
    email.to.first.should == member.email
    email.body.should.include url
  end
end}

# Controllers

# * Application controller

initializer 'mime_types.rb', %{Mime::Type.register 'image/jpeg', :jpg}

file 'app/controllers/application_controller.rb',
%{class ApplicationController < ActionController::Base
  helper :all
  protect_from_forgery
  filter_parameter_logging :password
  before_filter :find_authenticated, :block_access, :set_actionmailer_host
  # report_errors_to 'http://forestwatcher.example.com/#{name}', :username => 'forestwatcher', :password => 'secret'
  
  protected
  
  # Responds with a http status code and an error document
  def send_response_document(status)
    format = (request.format === [Mime::XML, Mime::JSON]) ? request.format : Mime::HTML
    status = interpret_status(status)
    send_file "\#{RAILS_ROOT}/public/\#{status.to_i}.\#{format.to_sym}",
      :status => status,
      :type => "\#{format}; charset=utf-8",
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
end}

file 'test/functional/application_controller_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

class TestApplicationsController < ApplicationController
  allow_access :admin, :only => :private_action
  allow_access :all, :except => :private_action
  
  def private_action
    render :nothing => true
  end
  
  def private_action_with_flash
    flash[:notice] = 'Message'
    render :nothing => true
  end
  
  def public_action
    render :nothing => true
  end
  
  def action_with_layout
    render :inline => '', :layout => 'application'
  end
  
  def action_with_respond_block
    respond_to do |format|
      format.html { render :text => 'HTML' }
      format.jpg { render :text => 'JPG'}
    end
  end
end

ActionController::Routing::Routes.draw do |map|
  map.resource :test_application, :member => {
    :private_action => :get,
    :private_action_with_flash => :get,
    :public_action => :get,
    :action_with_layout => :get,
    :action_with_respond_block => :get
  }
end

describe TestApplicationsController do
  it "should find the currently logged in member" do
    login members(:adrian)
    get :public_action
    assigns(:authenticated).should == members(:adrian)
  end
  
  it "should not find currently logged in member when no-one is logged in" do
    get :public_action
    assigns(:authenticated).should.be.blank
  end
  
  it "should log a member in" do
    should.not.be.authenticated
    @controller.send(:login, members(:adrian))
    should.be.authenticated
  end
  
  it "should log a member out" do
    @controller.send(:login, members(:adrian))
    should.be.authenticated
    @controller.send(:logout)
    should.not.be.authenticated
  end
  
  it "should respond with HTML before JPG" do
    request.env['HTTP_ACCEPT'] = "*/*"
    get :action_with_respond_block
    response.body.should == 'HTML'
  end
  
  it "should respond with HTML before JPG, even with IE" do
    request.env["HTTP_USER_AGENT"] = 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0; Win64; x64)'
    request.env['HTTP_ACCEPT'] = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, application/xaml+xml, application/vnd.ms-xpsdocument, application/x-ms-xbap, application/x-ms-application, application/x-shockwave-flash, application/x-silverlight, */*"
    get :action_with_respond_block
    response.body.should == 'HTML'
  end
end

describe TestApplicationsController, "when dealing with pages that need authorization" do
  it "should allow the user to authorize" do
    get :private_action
    should.redirect_to new_session_url
  end
  
  it "should keep the flash around when access was refused" do
    get :private_action_with_flash
    flash[:notice].should == 'Message'
  end
  
  it "should have stored the url to return the user to after authentication" do
   get :private_action
   controller.after_authentication[:redirect_to].should == controller.url_for(:action => :private_action)
  end
  
  it "should show a forbidden page when access was refused" do
    controller.stubs(:find_authenticated)
    controller.send(:instance_variable_set, "@authenticated", stub(:id => 1, :role => 'member'))
    
    get :private_action
    status.should.be :forbidden
  end
end}

# * Members controller

file 'app/controllers/members_controller.rb',
%{class MembersController < ApplicationController
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
end}

file 'test/functional/members_controller_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

describe "On the", MembersController, "a visitor" do
  it "should see a form for a new member" do
    get :new
    status.should.be :ok
    template.should.be 'members/new'
    assert_select 'form'
  end
  
  it "should create a new member" do
    lambda {
      post :create, :member => valid_params
    }.should.differ('Member.count', +1)
    assigns(:member).email.should == valid_params[:email]
    assigns(:member).hashed_password.should == Member.hash_password(valid_params[:password])
    should.redirect_to root_url
    should.be.authenticated
  end
  
  it "should show validation errors after a failed create" do
    post :create, :member => valid_params.merge(:email => '')
    status.should.be :ok
    template.should.be 'members/new'
    assert_select 'div.errorExplanation'
    assert_select 'form'
    should.not.be.authenticated
  end
  
  it "should see a profile" do
    get :show, :id => members(:adrian)
    assigns(:member).should == members(:adrian)
    status.should.be :success
    template.should.be 'members/show'
  end
  
  should.require_login.get :edit, :id => members(:adrian)
  should.require_login.put :update, :id => members(:adrian)
  should.require_login.delete :destroy, :id => members(:adrian)
  
  private
  
  def valid_params
    { :email => 'jurgen@example.com', :password => 'so secret', :verify_password => 'so secret' }
  end
end

describe "On the", MembersController, "a member" do
  before do
    login members(:adrian)
  end
  
  it "should see an edit form" do
    get :edit, :id => @authenticated.to_param
    
    assert_select 'form'
    assigns(:member).should == @authenticated
    status.should.be :success
    template.should.be 'members/edit'
  end
  
  it "should be able to update his profile" do
    put :update, :id => @authenticated.to_param, :member => { :email => 'sir.adrian@example.com' }
    
    @authenticated.reload.email.should == 'sir.adrian@example.com'
    should.redirect_to member_url(@authenticated)
  end
  
  should.disallow.put :update, :id => members(:kelly)
  should.disallow.delete :destroy, :id => members(:kelly)
end}

# * Passwords controller

file 'app/controllers/passwords_controller.rb',
%{require 'net/smtp'

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
    logger.error "\#{e.class} raised while trying to email: \#{e.message}\n\n\#{e.backtrace.join("\n")}"
    flash[:error] = "We're sorry, but your email could not be sent. Please try again later."
  end
end}

file 'test/functional/passwords_controller_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

describe "On the", PasswordsController, "a visitor" do
  before do
    @member = members(:adrian)
  end
  
  it "should see a new form to reset his password" do
    get :new
    status.should.be :success
    template.should.be 'passwords/new'
    assert_select 'form'
  end
  
  it "should generate a password reset token and send it via email" do
    @member.update_attribute(:reset_password_token, nil)
    
    assert_emails(1) do
      post :create, :email => @member.email
    end
    
    assigns(:member).should == @member
    @member.reload.reset_password_token.should.not.be.blank
    
    email = ActionMailer::Base.deliveries.last
    email.body.should.include edit_password_url(:id => @member.reset_password_token)
    
    status.should.be :success
    template.should.be 'passwords/sent'
  end
  
  it "should see an error if no member can be found for a given email address" do
    assert_emails(0) do
      post :create, :email => "joe.the.plumber@example.com"
    end
    
    status.should.be :ok
    template.should.be 'passwords/new'
    flash[:error].should.not.be.blank
  end
  
  it "should see a warning if an SMTP error occurred" do
    Mailer.stubs(:deliver_reset_password_message).raises Net::SMTPFatalError
    post :create, :email => @member.email
    
    status.should.be :ok
    template.should.be 'passwords/new'
    flash[:error].should.not.be.blank
  end
  
  it "should see an edit form for his password" do
    @member.generate_reset_password_token!
    get :edit, :id => @member.reset_password_token
    
    status.should.be :success
    assigns(:member).should == @member
    template.should.be 'passwords/edit'
    assert_select 'form'
  end
  
  it "should not see an edit form if no member is found for the given token" do
    get :edit, :id => "doesnotexist"
    
    status.should.be :not_found
    assigns(:member).should.be nil
  end
  
  it "should be able to update his password" do
    @member.generate_reset_password_token!
    put :update, :id => @member.reset_password_token, :password => "newpass"
    
    Member.authenticate(:email => @member.email, :password => "newpass").should == @member
    status.should.be :success
    template.should.be 'passwords/reset'
  end
  
  it "should see an error if the password is empty" do
    @member.generate_reset_password_token!
    before = @member.hashed_password
    
    put :update, :id => @member.reset_password_token, :password => ""
    
    @member.reload.hashed_password.should == before
    status.should.be :success
    template.should.be 'passwords/edit'
    assert_select "div.errorExplanation", :text => "The password can’t be blank."
  end
  
  it "should not be allowed to update a password with an incorrect token" do
    put :update, :id => "doesnotexist", :password => "newpass"
    
    status.should.be :not_found
    assigns(:member).should.be nil
  end
end}

# * Sessions controller

file 'app/controllers/sessions_controller.rb',
%{class SessionsController < ApplicationController
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
end}

file 'test/functional/sessions_controller_test.rb',
%{require File.expand_path('../../test_helper', __FILE__)

describe "On the", SessionsController, "a visitor" do
  it "should see a login form" do
    get :new
    status.should.be :success
    template.should.be 'sessions/new'
    assert_select 'form'
  end
  
  it "should keep the url to return to after authentication" do
    url = member_url(members(:adrian))
    get :new, {}, {}, { :after_authentication => { :redirect_to => url }}
    controller.after_authentication[:redirect_to].should == url
  end
  
  it "should be able to create a new session" do
    post :create, :member => valid_credentials
    assigns(:unauthenticated).should == members(:adrian)
    should.be.authenticated
    should.redirect_to root_url
  end
  
  it "should redirect the user back to the page he originally requested" do
    url = edit_member_url(members(:adrian))
    post :create, { :member => valid_credentials }, {}, { :after_authentication => { :redirect_to => url }}
    should.redirect_to url
  end
  
  it "should see an explanation if the password was wrong" do
    post :create, :member => valid_credentials.merge(:password => 'wrong')
    should.not.be.authenticated
    status.should.be :success
    assert_select 'div.errorExplanation'
  end
  
  it "should see an explanation when the email does not exist" do
    post :create, :member => valid_credentials.merge(:email => 'unknown@example.com')
    should.not.be.authenticated
    status.should.be :success
    assert_select 'div.errorExplanation'
  end
  
  it "should keep the url to return to if the password or email was wrong" do
    url = member_url(members(:adrian))
    post :create, { :member => valid_credentials.merge(:password => 'wrong') }, {}, { :after_authentication => { :redirect_to => url }}
    should.not.be.authenticated
    controller.after_authentication[:redirect_to].should == url
  end
  
  private
  
  def valid_credentials
    { :email => members(:adrian).email, :password => 'secret' }
  end
end

describe "On the", SessionsController, "a member" do
  before do
    login members(:adrian)
  end
  
  it "should be able to clear the logged in session" do
    get :clear
    should.not.be.authenticated
    should.redirect_to root_url
  end
end}

# * Helpers

file 'app/helpers/application_helper.rb',
%{module ApplicationHelper
def nav_link_to(label, url, options={})
  if current_page?(url)
    options[:class] ? options[:class] << ' current' : options[:class] = 'current'
  end
  link_to(label, url, options)
end

def nav_item(label, url, options={})
  shallow = options.delete(:shallow)
  
  classes = (options[:class] || '').split(' ')
  if (shallow and request.request_uri == url) or (!shallow and request.request_uri.start_with?(url))
    classes << 'current'
  end
  options[:class] = classes.empty? ? nil : classes.join(' ')
  
  content_tag(:li, link_to(label, url), options)
end}

file 'test/unit/helpers/application_helper_test.rb',
%{require File.expand_path('../../../test_helper', __FILE__)

describe ApplicationHelper, "concerning navigation" do
  attr_accessor :request
  before do
    @request    = stub(:request_uri => '/members')
    @controller = stub(:request => @request)
  end
  
  it "should generate a navigation link" do
    assert_dom_equal('<a href="/passwords/new">Reset password</a>',    nav_link_to('Reset password', '/passwords/new'))
    assert_dom_equal('<a href="/members" class="current">Members</a>', nav_link_to('Members', '/members'))
  end
  
  it "should generate a navigation item" do
    assert_dom_equal('<li><a href="/passwords/new">Reset password</a></li>', nav_item('Reset password', '/passwords/new'))
  end
  
  it "should generate a navigation item with extra options" do
    assert_dom_equal('<li class="first"><a href="/passwords/new">Reset password</a></li>', nav_item('Reset password', '/passwords/new', :class => 'first'))
  end
  
  it "should generate a navigation item when the current page is equal to the navigation item" do
    assert_dom_equal('<li class="current"><a href="/members">Members</a></li>', nav_item('Members', '/members'))
  end
  
  it "should generate a navigation item when the current page is equal to the navigation item with extra options" do
    assert_dom_equal('<li class="first current"><a href="/members">Members</a></li>', nav_item('Members', '/members', :class => 'first'))
  end
  
  it "should generate a navigation item when the current page is more specific than the navigation item" do
    @request = stub(:request_uri => '/members/12')
    assert_dom_equal('<li class="current"><a href="/members">Members</a></li>', nav_item('Members', '/members'))
  end
  
  it "should generate a shallow navigation item that doesn't become current when a subpage is viewed" do
    assert_dom_equal('<li><a href="/">Home</a></li>', nav_item('Home', '/', :shallow => true))
  end
  
  it "should generate a shallow navigation item that becomes current when the page it links to is viewed" do
    @request = stub(:request_uri => '/')
    assert_dom_equal('<li class="current"><a href="/">Home</a></li>', nav_item('Home', '/', :shallow => true))
  end
end}

# * Views

run 'rm public/index.html'

file 'public/403.html',
%{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">

<head>
  <meta http-equiv="content-type" content="text/html; charset=UTF-8" />
  <title>Access forbidden (403)</title>
  <style type="text/css">
    body { background-color: #fff; color: #666; text-align: center; font-family: arial, sans-serif; }
    div.dialog {
      width: 25em;
      padding: 0 4em;
      margin: 4em auto 0 auto;
      border: 1px solid #ccc;
      border-right-color: #999;
      border-bottom-color: #999;
    }
    h1 { font-size: 100%; color: #f00; line-height: 1.5em; }
  </style>
</head>

<body>
  <!-- This file lives in public/403.html -->
  <div class="dialog">
    <h1>Access forbidden.</h1>
  </div>
</body>
</html>}

file 'public/stylesheets/main.css', %{/* TODO: Need to add actualy default style rules. */}

file 'public/javascripts/ready.js',
%{// Let the javascript libs start their behaviour. These are all included at the
// end of the document so the browser will first render the document before
// requesting the javascripts.

// Event.observe(document, 'dom:loaded', function() {
// });

// Event.observe(window, 'load', function() {
// });}

file 'app/views/layouts/application.html.erb',
%{<!DOCTYPE html>
<html>
  <head>
    <%= render :partial => 'layouts/head' %>
  </head>
  <body>
    <div id="wrapper">
      <div id="header">
        <a id="logo" href="/">#{name.camelize}</a>
        <%= render :partial => 'sessions/status' %>
        
        <ul id="navigation">
          <%= nav_item 'Home', root_path, :class => 'first', :shallow => true %>
          <%= nav_item 'Members', members_path, :class => 'last' %>
        </ul>
      </div>
      
      <div id="main">
        <%= yield :layout %>
      </div>
    </div>
    
    <%= render :partial => 'layouts/application_javascript_includes' %>
  </body>
</html>}

file 'app/views/layouts/_application_javascript_includes.html.erb',
%{<%#= javascript_include_tag(%w(prototype effects controls) +
 %w() + # add app specific libs
 %w(ready), :cache => (Rails.env == 'production')) %>}

file 'app/views/layouts/_head.html.erb',
%{<meta charset="UTF-8">
<title><%=h [@title, '#{name.camelize}'].compact.join(' ‹ ') %></title>
<%= stylesheet_link_tag 'main', :media => 'screen' %>}

# * * Members views

file 'app/views/members/new.html.erb',
%{<% @title = 'Sign up' %>

<div>
  <% form_for @member do |f| %>
    <h2>Sign up</h2>
    
    <%= error_messages_for :member %>
    
    <div class="fields">
      <div class="field">
        <div class="label"><%= f.label :email %></div>
        <div class="field"><%= f.text_field :email %></div>
      </div>
      
      <div class="field">
        <div class="label"><%= f.label :password %></div>
        <div class="field"><%= f.password_field :password %></div>
      </div>
      
      <div class="submit">
        <%= f.submit 'Sign up' %>
        <%= link_to 'Back', root_path, :class => 'cancel' %>
      </div>
    </div>
  <% end %>
</div>}

file 'app/views/members/show.html.erb', %{Member show: <%= @member.email %>}

file 'app/views/members/edit.html.erb',
%{<% @title = 'Edit profile' %>

<div>
  <% form_for @member do |f| %>
    <h2>Edit profile</h2>
    
    <%= error_messages_for :member %>
    
    <div class="fields">
      <div class="field">
        <div class="label"><%= f.label :email %></div>
        <div class="field"><%= f.text_field :email %></div>
      </div>
      
      <div class="submit">
        <%= f.submit 'Update profile' %>
        <%= link_to 'Back', root_path, :class => 'cancel' %>
      </div>
    </div>
  <% end %>
</div>}

# * * Passwords views

file 'app/views/passwords/new.html.erb',
%{<% @title = 'Choose a new password' %>

<div>
  <% form_tag passwords_path do %>
    <h2>Forgot password?</h2>
    <p>Please enter your email address and we’ll send further instructions on how to choose a new password.</p>
    
    <% unless flash[:error].blank? %>
      <div class="errorExplanation"><%= flash[:error] %></div>
    <% end %>
    
    <div class="field">
      <span class="label"><%= label_tag :email, 'Email address' %></span>
      <%= text_field_tag :email %>
    </div>
    
    <div class="submit">
      <%= submit_tag 'Continue' %>
      <%= link_to 'Cancel', root_path, :class => 'cancel' %>
    </div>
  <% end %>
</div>}

file 'app/views/passwords/sent.html.erb',
%{<% @title = 'Choose a new password' %>

<div>
  <% form_tag root_path, :method => :get do %>
    <h2>Forgot password?</h2>
    <p>We’ve sent further instructions on how to choose a new password by email.</p>
    <div>
      <%= submit_tag 'Okay' %>
    </div>
  <% end %>
</div>}

file 'app/views/passwords/edit.html.erb',
%{<div>
  <% form_tag password_path(:id => @member.reset_password_token), :method => :put do %>
    <h2><%= @title = 'Choose a new password' %></h2>
    <p>You’ll be able to log in after you’ve chosen a new password.</p>
    
    <% if @member.errors.on(:password) %>
      <div class="errorExplanation">The password can’t be blank.</div>
    <% end %>
    
    <div>
      <span class="label"><%= label_tag :password, 'New password' %></span>
      <%= password_field_tag :password %>
    </div>
    
    <div>
      <%= submit_tag 'Continue' %>
      <%= link_to 'Cancel', root_path, :class => 'cancel' %>
    </div>
  <% end %>
</div>}

file 'app/views/passwords/reset.html.erb',
%{<div>
  <% form_tag new_session_path, :method => :get do %>
    <h2><%= @title = 'Choose a new password' %></h2>
    <p>Your password has been changed.</p>
    <div>
      <%= submit_tag 'Okay' %>
    </div>
  <% end %>
</div>}

# * * Sessions views

file 'app/views/sessions/new.html.erb',
%{<% @title = 'Log in' %>

<div>
  <%= render :partial => 'sessions/form' %>
</div>}

file 'app/views/sessions/_form.html.erb',
%{<% form_for(@unauthenticated || Member.new, :url => session_path) do |f| %>
  <h2>Log in</h2>
  
  <% if flash[:login_error] %>
    <div class="errorExplanation"><%= flash[:login_error] %></div>
  <% end %>
  
  <div class="field">
    <span class="label"><%= f.label :email %></span>
    <%= f.text_field :email, :tabindex => 1 %>
  </div>
  
  <div class="field">
    <span class="label"><%= f.label :password %> <%= link_to 'forgot password?', new_password_path, :tabindex => 5 %></span>
    <%= f.password_field :password, :tabindex => 2 %>
  </div>
  
  <div class="field inline">
    <%= check_box_tag :remember_me, 1, false, :tabindex => 3 %>
    <%= label_tag :remember_me %>
  </div>
  
  <div class="field">
    <%= f.submit 'Log in', :tabindex => 4 %>
    <%= link_to 'Cancel', root_path, :class => 'cancel', :tabindex => 5 %>
  </div>
<% end %>}

file 'app/views/sessions/_status.html.erb',
%{<p id="member">
  <% if @authenticated %>
    <%= nav_link_to 'Profile', @authenticated %>
    <%= link_to 'Log out', clear_session_path %>
  <% else %>
    <%= nav_link_to 'Log in', new_session_path, 'class' => 'login' %>
    <%= nav_link_to 'Sign up', new_member_path %>
  <% end %>
</p>}

# * * Mailer views

file 'app/views/mailer/reset_password_message.erb',
%{Hi,

Forgot your password? Click the following link to choose a new password:

<%= @url %>

Kind regards,
#{name.camelize}}

# Finalize

rake 'db:create:all'
rake 'db:migrate'

exec 'rake test' if yes?('Would you like to run the test suite? [Y/n]')