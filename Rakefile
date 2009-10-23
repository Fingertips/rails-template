desc 'Runs the template with the proper env so that it caches the rails checkout.'
task :test_template do
  sh 'env TEST_TEMPLATE=true rails -m fingertips.rb test_app'
end

task :default => :test_template