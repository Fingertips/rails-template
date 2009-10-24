desc 'Drops the databases and removes the test app.'
task :clean do
  sh 'cd test_app && rake db:drop:all'
  rm_rf 'test_app'
end

desc 'Runs the template with the proper env so that it caches the rails checkout.'
task :test_template => :clean do
  sh 'env TEST_TEMPLATE=true rails -m fingertips.rb test_app'
end

task :default => :test_template