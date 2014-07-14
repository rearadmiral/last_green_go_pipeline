# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'bundler/version'

Gem::Specification.new do |s|
  s.name        = "last_green_go_pipeline"
  s.version     = "1.1.2"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bill DePhillips"]
  s.email       = ["bill.dephillips@gmail.com"]
  s.licenses    = ['MIT']
  s.homepage    = "https://github.com/rearadmiral/last_green_go_pipeline"
  s.summary     = "last green Go.CD pipeline fetcher"
  s.description = "friendly wrapper around the go-api-client that looks up the last green build of a Go.CD pipeline"

  s.rubyforge_project         = "last_green_go_pipeline"

  s.add_development_dependency "rspec", '~> 3.0'
  s.add_runtime_dependency "go_cd_feed", '~> 1.1'

  s.files        = Dir.glob("{lib}/**/*") + %w(LICENSE README.md)
  s.require_path = 'lib'
end
