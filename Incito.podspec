Pod::Spec.new do |s|

    s.name            = "Incito"
    s.version         = "1.0.5"
    s.summary         = "Incito viewer for iOS."
    s.description     = <<-DESC
                         A library for loading and viewing Incito-format documents.
                        DESC
    s.homepage         = "https://github.com/tjek/incito-ios"
    s.license          = "MIT"
    s.author           = "Tjek"

    s.platform         = :ios, "9.3"
    s.swift_version    = "5.0.1"
    s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }

    s.source       = { :git => "https://github.com/tjek/incito-ios.git", :tag => "v#{s.version}" }
    
    s.source_files = "Sources/**/*.{swift,h,m}"
    s.resources = ["Sources/**/Resources/**/*.strings", "Sources/**/*.html"]
end
