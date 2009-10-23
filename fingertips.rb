# TODO: For client apps we want to add some arg (ENV) to choose between a OSS
# git project and a closed svn one. The svn version should install gems instead
# of creating checkouts of the git libs in vendor/plugins.

require 'fileutils'

# Rails
if ENV['TEST_TEMPLATE'] && File.exist?('../rails')
  puts '[!] Using rails cache...'
  run 'cp -R ../rails vendor/'
else
  # On 2.3.4 the git command is broken as it only executes in_root...
  inside 'vendor' do
    Git.run 'clone git://github.com/Fingertips/rails.git'
    run 'cd rails && git remote add rails git://github.com/rails/rails.git'
  end
  if ENV['TEST_TEMPLATE']
    puts '[!] Creating rails cache...'
    run 'cp -R vendor/rails ../'
  end
end

# Plugins
plugin 'authentication-needed-san', :git => 'git://github.com/Fingertips/authentication-needed-san.git'
plugin 'authorization-san',         :git => 'git://github.com/Fingertips/authorization-san.git'
plugin 'generator-san',             :git => 'git://github.com/Fingertips/generator-san.git'
plugin 'peiji-san',                 :git => 'git://github.com/Fingertips/peiji-san.git'
plugin 'on-test-spec',              :git => 'git://github.com/Fingertips/on-test-spec.git'

# Gems
environment "config.gem 'test-spec', :version => '~> 0.10.0'", :env => :test
rake 'gems:install', :env => :test, :sudo => true

# Database
if yes? 'Use MySQL instead of SQLite?'
  name = File.basename(root)
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
rake 'db:create:all'
rake 'db:migrate'

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
  file 'authentication',
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
  
  file 'file_fixtures',
%{module TestHelpers
  module FileFixtures
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
      ActionController::TestUploadedFile.new("\#{fixture_path}\#{path}", mime_type, binary)
    end
  end
end}
  
  file 'time',
%{module TestHelpers
  module Time
    def freeze_time!(time = ::Time.parse('6/1/2009'))
      ::Time.stubs(:now).returns(time)
      time
    end
  end
end}
end