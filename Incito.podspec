Pod::Spec.new do |s|

    s.name            = "Incito"
    s.version         = "0.1"
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
    
    s.subspec 'Core' do |ss|
        ss.source_files = ["Sources/Core/**/*.swift", "Sources/Utils/**/*.swift"]
        ss.frameworks   = "Foundation"
    end

    s.subspec 'UIKit' do |ss|
        ss.source_files = "Sources/UIKit/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit"

        ss.dependency "Incito/Core"
        ss.dependency "SVGKit"
        ss.dependency "FLAnimatedImage", "~> 1.0"
    end
end
