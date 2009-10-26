require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'tasks/rails'

namespace :test do
  desc "Run the javascript tests in test/javascripts"
  task :javascripts do
    sh "jstest #{Dir['test/javascripts/*.html'].join(' ')}"
  end
  
  Rake::TestTask.new('lib') do |t|
    t.test_files = FileList['test/lib/**/*_test.rb']
    t.verbose = true
  end
end

task :test do
  Rake::Task['test:lib'].invoke
  Rake::Task['test:javascripts'].invoke
end