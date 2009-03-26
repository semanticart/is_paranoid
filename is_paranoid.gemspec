# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{is_paranoid}
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jeffrey Chupp"]
  s.date = %q{2009-03-26}
  s.description = %q{}
  s.email = %q{jeff@semanticart.com}
  s.extra_rdoc_files = ["README.textile"]
  s.files = ["README.textile", "VERSION.yml", "lib/is_paranoid.rb", "spec/android_spec.rb", "spec/database.yml", "spec/schema.rb", "spec/spec.opts", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/jchupp/is_paranoid/}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{ActiveRecord 2.3 compatible gem "allowing you to hide and restore records without actually deleting them."  Yes, like acts_as_paranoid, only with less code and less complexity.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, [">=2.3.0"])
    else
      s.add_dependency(%q<activerecord>, [">=2.3.0"])
    end
  else
    s.add_dependency(%q<activerecord>, [">=2.3.0"])
  end
end