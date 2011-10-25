# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cap-elb/version"

Gem::Specification.new do |s|
	s.name        = "cap-elb"
	s.version     = Cap::Elb::VERSION
	s.authors     = ["Dan Miley"]
	s.email       = ["dan.miley@gmail.com"]
	s.homepage    = "http://github.com/danmiley/cap-elb"
	s.summary     = %q{Capistrano can perform tasks on Amazon ELB instances}
	s.description = %q{Capistrano can perform tasks on Amazon ELB instances; various arguments to allow instance tags to determine whether task should be applied on the given tag}

	s.rubyforge_project = "cap-elb"

	s.files         = `git ls-files`.split("\n")
	s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
	s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
	s.require_paths = ["lib"]

	s.add_dependency "right_aws", "2.1.0"
	s.add_development_dependency "rspec", "~> 2.6"


end
