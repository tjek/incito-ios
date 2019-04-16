//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import AVKit
import AVFoundation

class VideoView: UIView {
    
    let spinner = UIActivityIndicatorView(style: .whiteLarge)
    
    let videoProperties: VideoViewProperties
    
    var playerController: AVPlayerViewController?
    var player: AVPlayer?
    
    var stateObserver: NSKeyValueObservation?
    var timeControlObserver: NSKeyValueObservation?

    init(frame: CGRect, videoProperties: VideoViewProperties) {
        self.videoProperties = videoProperties
        super.init(frame: frame)
        
        try? AVAudioSession.sharedInstance().setCategory(.ambient)

        spinner.frame = {
            var frame = spinner.frame
            frame.origin.x = self.bounds.midX - (frame.size.width / 2)
            frame.origin.y = self.bounds.midY - (frame.size.height / 2)
            return frame
        }()
        self.addSubview(spinner)
        spinner.startAnimating()
        
        player = AVPlayer(url: videoProperties.source)
        player?.isMuted = videoProperties.autoplay // always mute if autoplay enabled
        
        stateObserver = player?.currentItem?.observe(\.status) { [weak self] _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.playerContentLoaded()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func playerContentLoaded() {
        playerController = AVPlayerViewController()
        playerController?.player = player
        playerController?.view.frame = self.bounds
        playerController?.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(playerController!.view, at: 0)
        
        playerController?.showsPlaybackControls = videoProperties.controls
        playerController?.videoGravity = .resizeAspect

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachTheEndOfTheVideo(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: self.player?.currentItem
        )
        
        if videoProperties.autoplay {
            player?.play()
        }
        
        if #available(iOS 10.0, *),
            player?.currentItem?.status == .readyToPlay,
            player?.timeControlStatus != .playing,
            videoProperties.autoplay == true
        {

            // if the video successfully autoplays, but is not playing because it is partially loaded, grey-out and keep showing spinner until it starts playing

            self.playerController?.view.layer.opacity = 0.6
            timeControlObserver = player?.observe(\.timeControlStatus) { [weak self] (player, _) in
                DispatchQueue.main.async { [weak self] in
                    if player.timeControlStatus == .playing {
                        
                        self?.spinner.stopAnimating()
                        self?.spinner.isHidden = true
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            self?.playerController?.view.alpha = 1
                        })
                        
                        self?.timeControlObserver = nil
                    }
                }
            }
        } else {
            self.spinner.stopAnimating()
            self.spinner.isHidden = true
        }
    }
    
    @objc func reachTheEndOfTheVideo(_ notification: Notification) {
        if videoProperties.loop {
            player?.pause()
            player?.seek(to: .zero)
            player?.play()
        }
    }
}
