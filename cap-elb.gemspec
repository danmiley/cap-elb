# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cap-elb/version"

Gem::Specification.new do |s|
  s.name        = "cap-elb"
  s.version     = Cap::Elb::VERSION
  s.authors     = ["Dan Miley"]
  s.email       = ["dan.miley@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Capistrano can perform tasks on Amazon ELB instances}
  s.description = %q{Capistrano can perform tasks on Amazon ELB instances}

  s.rubyforge_project = "cap-elb"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
