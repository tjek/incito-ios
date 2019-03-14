//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension UIView {
    
    func addImageView(
        imageProperties: ImageViewProperties,
        renderableView: RenderableView
        ) -> ImageViewLoadRequest {
        
        let size = self.bounds.size
        let transform: (UIImage) -> UIImage = { oldImage in
            oldImage.resized(scalingType: .centerCrop, into: size)
        }
        
        let stillVisibleCheck: () -> Bool = { [weak self] in self != nil }
        
        let imageLoadReq = ImageViewLoadRequest(url: imageProperties.source, containerSize: size, transform: transform, stillVisibleCheck: stillVisibleCheck) { [weak self] loadedImageView in
            guard let c = self else { return }
            guard let imageView = loadedImageView else { return }
            
            imageView.contentMode = .scaleToFill
            imageView.frame = c.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageView.alpha = 0
            c.insertSubview(imageView, at: 0)
            
            // only fade it the renderable view is on screen
            if renderableView.isVisible {
                UIView.animate(withDuration: 0.2) {
                    imageView.alpha = 1
                }
            } else {
                imageView.alpha = 1
            }
        }
        
        return imageLoadReq
    }
    
    func addVideoView(
        videoProperties: VideoViewProperties
        ) {
        let videoView = VideoView(frame: self.bounds, videoProperties: videoProperties)
        self.insertSubview(videoView, at: 0)
    }
    
    func addVideoEmbedView(
        videoProperties: VideoEmbedViewProperties
        ) {
        let videoView = VideoEmbedView(frame: self.bounds, videoProperties: videoProperties)
        videoView.didTapURL = { url in
            UIApplication.shared.openURL(url)
        }
        self.insertSubview(videoView, at: 0)
    }
}

extension UIView {
    
    func applyStyle(_ style: StyleProperties) -> ImageViewLoadRequest? {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        
        var imageLoadReq: ImageViewLoadRequest? = nil
        if let bgImage = style.backgroundImage {
            
            let size = self.bounds.size
            let transform: (UIImage) -> UIImage = { oldImage in
                oldImage.resized(
                    scalingType: bgImage.scale,
                    tilingMode: bgImage.tileMode,
                    position: bgImage.position,
                    into: size
                )
            }
            let stillVisibleCheck: () -> Bool = { [weak self] in self != nil }
            
            imageLoadReq = ImageViewLoadRequest(url: bgImage.source, containerSize: size, transform: transform, stillVisibleCheck: stillVisibleCheck) { [weak self] loadedImageView in
                guard let self = self else { return }
                guard let imageView = loadedImageView else { return }
                
                imageView.frame = self.bounds
                
                // use gravity to define the position
                imageView.layer.contentsGravity = bgImage.position.contentsGravity(
                    isFlipped: self.layer.contentsAreFlipped()
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
