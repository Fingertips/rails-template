# * Use plugins or gems?
# * Add an option which prepares the app for svn usage.

require 'fileutils'

TEMPLATE_HOME = ENV['TEMPLATE_HOME'] ||
  'http://github.com/Fingertips/rails-template/raw/master/templates/'

class Rails::TemplateRunner
  def name
    File.basename(root)
  end
  
  def template_file(template)
    contents = open(File.join(TEMPLATE_HOME, template)).read
    contents.gsub!('{{app_name}}', name)
    contents.gsub!('{{AppName}}', name.camelize)
    file template, contents
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

# Setup

template_file 'config/database.yml'

# Gems

environment "gem 'test-spec', :version => '~> 0.10.0', :lib => 'test/spec'", :env => :test
rake 'gems:install', :env => :test, :sudo => true

# Rails

test_cache 'rails' do
  # On 2.3.4 the git command is broken as it only executes in_root
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
  plugin 'on-test-spec',              :git => 'git://github.com/Fingertips/on-test-spec.git'
  plugin 'peiji-san',                 :git => 'git://github.com/Fingertips/peiji-san.git'
  plugin 'risosu-san',                :git => 'git://github.com/Fingertips/risosu-san.git'
  plugin 'validates_email-san',       :git => 'git://github.com/Fingertips/validates_email-san.git'
end

# Misc

template_file '.kick'
template_file 'Rakefile'

# Test

template_file 'test/test_helper.rb'
template_file 'test/ext/authentication.rb'
template_file 'test/ext/file_fixtures.rb'
template_file 'test/ext/time.rb'

# Lib

initializer 'core_ext.rb',
%{require 'active_record_ext'

ActiveRecord::Base.send(:extend, ActiveRecord::Ext)
ActiveRecord::Base.send(:include, ActiveRecord::BasicScopes)}

template_file 'lib/active_record_ext.rb'
template_file 'test/lib/active_record_ext_test.rb'

template_file 'lib/token.rb'
template_file 'test/lib/token_test.rb'

####
#
# Application template
#

initializer 'application.rb', %{SYSTEM_EMAIL_ADDRESS = '#{name.camelize} Support <support@example.com>'}

# Routes

# For some reason these routes are generated in the reversed order...
route 'map.root :controller => "members", :action => "new"'
route 'map.resource  :session, :collection => { :clear => :get }'
route 'map.resources :passwords'
route 'map.resources :members'

# Models

generate :model_san, 'member role:string email:string hashed_password:string reset_password_token:string'

template_file 'app/models/member.rb'
template_file 'test/unit/member_test.rb'
template_file 'test/fixtures/members.yml'

template_file 'app/models/member/authentication.rb'
template_file 'test/unit/member/authentication_test.rb'

template_file 'app/models/mailer.rb'
template_file 'test/unit/mailer_test.rb'

# Controllers

initializer 'mime_types.rb', %{Mime::Type.register 'image/jpeg', :jpg}

template_file 'app/controllers/application_controller.rb'
template_file 'test/functional/application_controller_test.rb'

template_file 'app/controllers/members_controller.rb'
template_file 'test/functional/members_controller_test.rb'

template_file 'app/controllers/passwords_controller.rb'
template_file 'test/functional/passwords_controller_test.rb'

template_file 'app/controllers/sessions_controller.rb'
template_file 'test/functional/sessions_controller_test.rb'

# Helpers

template_file 'app/helpers/application_helper.rb'
template_file 'test/unit/helpers/application_helper_test.rb'

# Views

run 'rm public/index.html'

template_file 'public/403.html'
template_file 'public/stylesheets/default.css'
template_file 'public/javascripts/ready.js'

template_file 'app/views/layouts/application.html.erb'
template_file 'app/views/layouts/_application_javascript_includes.html.erb'
template_file 'app/views/layouts/_head.html.erb'

template_file 'app/views/members/new.html.erb'
template_file 'app/views/members/show.html.erb'
template_file 'app/views/members/edit.html.erb'

template_file 'app/views/passwords/new.html.erb'
template_file 'app/views/passwords/sent.html.erb'
template_file 'app/views/passwords/edit.html.erb'
template_file 'app/views/passwords/reset.html.erb'

template_file 'app/views/sessions/new.html.erb'
template_file 'app/views/sessions/_form.html.erb'
template_file 'app/views/sessions/_status.html.erb'

template_file 'app/views/mailer/reset_password_message.erb'

# Finalize

rake 'db:create:all'
rake 'db:migrate'

exec 'rake test'