require "spec"
require "spec/rake/spectask"
require 'lib/is_paranoid.rb'

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
  t.spec_files = FileList['spec/**/*_spec.rb']
end

task :install do
  rm_rf "*.gem"
  puts `gem build is_paranoid.gemspec`
  puts `sudo gem install is_paranoid-0.0.1.gem`
end