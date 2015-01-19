Pod::Spec.new do |s|
  s.name         = "SwiftHTTP"
  s.version      = "0.9.1"
  s.summary      = "Thin wrapper around NSURLSession in Swift. Simplifies HTTP requests."
  s.homepage     = "https://github.com/daltoniam/SwiftHTTP"
  s.license      = 'Apache License, Version 2.0'
  s.author       = {'Dalton Cherry' => 'http://daltoniam.com'}
  s.source       = { :git => 'https://github.com/daltoniam/SwiftHTTP.git',  :tag => "#{s.version}"}
  s.social_media_url = 'http://twitter.com/daltoniam'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.source_files = '*.swift'
  s.requires_arc = 'true'
end
