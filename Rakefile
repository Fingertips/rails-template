begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "fingerrails"
    s.summary = s.description = "A self contained version of the Fingertips Rails template"
    s.email = "eloy@fngtps.com"
    s.homepage = "http://github.com/Fingertips/rails-template"
    s.authors = ["Manfred Stienstra", "Eloy Duran"]
    
    s.require_paths = ['bin']
  end
rescue LoadError
end

desc 'Drops the databases and removes the test app.'
task :clean do
  if File.exist? 'test_app'
    sh 'cd test_app && rake db:drop:all' rescue nil
    rm_rf 'test_app'
  end
end

desc 'Runs the template with the proper env so that it caches the rails checkout.'
task :test_template => :clean do
  sh 'env TEST_TEMPLATE=true ruby ./bin/fingerrails test_app'
end

task :default => :test_template