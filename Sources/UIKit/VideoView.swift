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

    var enterBackgroundNotifToken: NSObjectProtocol?
    var becomeActiveNotifToken: NSObjectProtocol?
    
    init(frame: CGRect, videoProperties: VideoViewProperties) {
        self.videoProperties = videoProperties
        super.init(frame: frame)
        
        print("🌈 CREATING \(Unmanaged.passUnretained(self).toOpaque()) \(videoProperties.source.lastPathComponent)")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        if #available(iOS 10.0, *) {
            try? audioSession.setCategory(.ambient, mode: .default)
        } else {
            let selector = NSSelectorFromString("setCategory:error:")
            if audioSession.responds(to: selector) {
                audioSession.perform(selector, with: AVAudioSession.Category.ambient)
            }
        }

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
        
        enterBackgroundNotifToken = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [unowned self] _ in
            self.playerController?.player = nil
            
            if #available(iOS 10.0, *) {
                print("🌈 didEnterBackground \(Unmanaged.passUnretained(self).toOpaque()) \(self.videoProperties.source.lastPathComponent)", self.player?.timeControlStatus.rawValue)
            }
        }
        
        becomeActiveNotifToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [unowned self] _ in
//            self?.playerController?.player = nil
            self.playerController?.player = self.player
            if #available(iOS 10.0, *) {
                print("🌈 didBecomeActive \(Unmanaged.passUnretained(self).toOpaque()) \(self.videoProperties.source.lastPathComponent)", self.player?.timeControlStatus.rawValue)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let token = becomeActiveNotifToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = enterBackgroundNotifToken {
            NotificationCenter.default.removeObserver(token)
        }
        print("🌈 DEINIT \(Unmanaged.passUnretained(self).toOpaque()) \(self.videoProperties.source.lastPathComponent)")
    }
    func playerContentLoaded() {
        print("🌈 playerContentLoaded \(Unmanaged.passUnretained(self).toOpaque()) \(self.videoProperties.source.lastPathComponent)", self.player?.currentItem?.status.rawValue)

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
                    
                    print("🌈 timeControlStatus changed \(player.timeControlStatus)", player.timeControlStatus.rawValue)
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
