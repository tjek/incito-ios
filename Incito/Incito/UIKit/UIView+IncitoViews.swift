//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import AVFoundation
import WebKit

extension UIView {
    
    func addTextView(
        textProperties: TextViewProperties,
        fontProvider: FontProvider,
        textDefaults: TextViewDefaultProperties,
        padding: Edges<Double>,
        intrinsicSize: Size<Double?>
        ) {
        
        let size = Size<Double>(cgSize: self.bounds.size)
        
        let label = UILabel()
        
        if let s = textProperties.shadow {
            label.layer.applyShadow(s)
        }
        
        // TODO: cache these values from when doing the layout phase
        let attributedString = textProperties.attributedString(
            fontProvider: fontProvider,
            defaults: textDefaults
        )
        
        label.attributedText = attributedString
        label.numberOfLines = textProperties.maxLines
        
        label.textAlignment = (textProperties.textAlignment ?? .left).nsTextAlignment
        label.lineBreakMode = .byTruncatingTail
        label.backgroundColor = .clear
        
        // labels are vertically aligned in incito, so add to a container view
        self.insertSubview(label, at: 0)
        
        let containerInnerSize = size.inset(padding)
        let textHeight: Double = {
            if let h = intrinsicSize.height {
                return h
            }
            // it may not have an intrinsic height calculated yet (eg. if the view container has absolute height specified)
            return Double(ceil(label.sizeThatFits(CGSize(width: containerInnerSize.width, height: 0)).height))
        }()
        
        label.frame = CGRect(
            origin: CGPoint(
                x: padding.left,
                y: padding.top
            ),
            size: CGSize(
                width: containerInnerSize.width,
                height: textHeight
            )
        )
        label.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
    }
    
    
    func addImageView(
        imageProperties: ImageViewProperties
        ) -> ImageViewLoadRequest {
        
        let size = self.bounds.size
        let transform: (UIImage) -> UIImage = { oldImage in
            //            measure("⏱ Resize Img \(oldImage.size) x\(oldImage.scale) -> \(size)", timeScale: .milliseconds) {
            oldImage.resized(scalingType: .centerCrop, into: size)
            //            }.result
        }
        
        let imageLoadReq = ImageViewLoadRequest(url: imageProperties.source, transform: transform) { [weak self] loadedImageView in
            guard let c = self else { return }
            guard let imageView = loadedImageView else { return }
            
            imageView.contentMode = .scaleToFill
            imageView.frame = c.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageView.alpha = 0
            c.insertSubview(imageView, at: 0)
            
            UIView.animate(withDuration: 0.2) {
                imageView.alpha = 1
            }
        }
        
        return imageLoadReq
    }
    
    func addVideoView(
        videoProperties: VideoViewProperties
        ) {
        
        let size = self.bounds.size
        
        let player = AVPlayer(playerItem:
            AVPlayerItem(
                asset: AVAsset(url: videoProperties.source),
                automaticallyLoadedAssetKeys: ["playable"])
        )
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = CGRect(origin: .zero, size: size)
        
        self.layer.addSublayer(playerLayer)
        
        if videoProperties.loop {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main) { [weak player] _ in
                    player?.seek(to: CMTime.zero)
                    player?.play()
            }
        }
        
        if videoProperties.autoplay == true {
            playerLayer.player?.play()
        }
    }
    
    func addVideoEmbedView(
        videoProperties: VideoEmbedViewProperties
        ) {
        
        let size = self.bounds.size
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size),
                                configuration: config)
        self.addSubview(webView)
        
        // TODO: dynamic loading/show loading state
        
        webView.scrollView.isScrollEnabled = false
        let request = URLRequest(url: videoProperties.source)
        
        webView.load(request)
    }
}

extension UIView {
    
    func applyStyle(_ style: StyleProperties) -> ImageViewLoadRequest? {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        var imageLoadReq: ImageViewLoadRequest? = nil
        if let bgImage = style.backgroundImage {
            
            let size = self.bounds.size
            let transform: (UIImage) -> UIImage = { oldImage in
                //                measure("⏱ Resize BGImg \(oldImage.size) x\(oldImage.scale) -> \(size)", timeScale: .milliseconds) {
                oldImage.resized(scalingType: bgImage.scale, into: size)
                //                }.result
            }
            
            imageLoadReq = ImageViewLoadRequest(url: bgImage.source, transform: transform) { [weak self] loadedImageView in
                guard let self = self else { return }
                guard let imageView = loadedImageView else { return }
                
                imageView.frame = self.bounds
                imageView.applyBackground(
                    position: bgImage.position,
                    scalingType: bgImage.scale,
                    tilingMode: bgImage.tileMode
                )
                
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.alpha = 0
                self.insertSubview(imageView, at: 0)
                
                UIView.animate(withDuration: 0.2) {
                    imageView.alpha = 1
                }
            }
        }
        
        return imageLoadReq
    }
}
