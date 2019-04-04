Pod::Spec.new do |s|

    s.name            = "Incito"
    s.version         = "0.3"
    s.summary         = "Incito viewer for iOS."
    s.description     = <<-DESC
                         A library for loading and viewing Incito-format documents.
                        DESC
    s.homepage         = "https://github.com/shopgun/incito-ios"
    s.license          = "MIT"
    s.author           = "ShopGun"
    s.social_media_url = "http://twitter.com/ShopGun"

    s.platform         = :ios, "9.3"
    s.swift_version    = "4.2"
    s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.2' }

    s.source       = { :git => "https://github.com/shopgun/incito-ios.git", :tag => "v#{s.version}" }
    
    s.source_files = "Sources/**/*.swift"
    s.resources = ["Sources/**/Resources/**/*.strings"]
    
    s.dependency "FLAnimatedImage", "~> 1.0"
    s.dependency "Cache", "~> 5.2"
    
    # As `Cache` is causing some problems in Xcode 10.2, this is a fix to avoid build-errors
    # See https://github.com/hyperoslo/Cache/issues/238 & https://stackoverflow.com/a/55416737/318834
    s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Osize' }
end
