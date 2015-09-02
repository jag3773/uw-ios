//
//  AudioPlayerView.swift
//  UnfoldingWord
//
//  Created by David Solberg on 8/31/15.
//  Copyright (c) 2015 Acts Media Inc. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class AudioPlayerView : UIView, AVAudioPlayerDelegate {
    
    var player : AVAudioPlayer?
    var timer : NSTimer?
    var url : NSURL?
    
    var downloader : FileDownloader?
    
    var audioData : NSData?
    
    @IBOutlet weak var sliderTime: UISlider!
    @IBOutlet weak var labelTimeLeading: UILabel!
    @IBOutlet weak var labelTimeTrailing: UILabel!
    @IBOutlet weak var buttonPlayPause: UIButton!
    @IBOutlet weak var labelDownloading: UILabel!
    
    var currentTime : NSTimeInterval {
        get {
            if let player = self.player {
                return player.currentTime
            }
            else {
                return 0.0
            }
        }
    }
    
    var duration : NSTimeInterval {
        get {
            if let player = self.player {
                return player.duration
            }
            else {
                return 0.0
            }
        }
    }
    
    var isReady : Bool {
        get {
            if let _ = self.player, _ = self.audioData {
                return true
            }
            else {
                return false
            }
        }
    }
    
    @objc class func playerWithUrl(url : NSURL) -> AudioPlayerView? {
        
        let nibViews = NSBundle.mainBundle().loadNibNamed("AudioPlayerView", owner: nil, options: nil)
        let playerView = nibViews[0] as! AudioPlayerView
        playerView.url = url
        playerView.downloadData()
        playerView.updateTimeUI()
        return playerView
    }
    
    required init(coder aDecoder: NSCoder) {
        self.player = nil
        super.init(coder: aDecoder)
    }
    
    deinit {
        unscheduleCurrentTimer()
    }
    
    // Outside Methods
    
    func downloadData() {
        
        if let url = self.url where self.player == nil {
            self.downloader = FileDownloader(url: url, progress: {[weak self] (percentDone) -> () in
                if let strongself = self {
                    strongself.updateDownloadPercentDone(percentDone)
                }
                }, completion: {[weak self] (success, data) -> () in
                    if let strongself = self, audioData = data where success {
                        strongself.createPlayerWithData(audioData)
                        strongself.showPlayerUI()
                        if strongself.superview != nil {
                            strongself.playAtTime(0)
                        }
                    }
                })
            self.downloader?.download()
            showDownloadingUI()
        }
    }
    
    func showDownloadingUI() {
        setDownloadingUIOn(true)
    }
    
    func showPlayerUI() {
        setDownloadingUIOn(false)
    }
    
    func setDownloadingUIOn(isDownloadingOn : Bool) {
        
        let playOpacity : Float = isDownloadingOn ? 0.0 : 1.0
        let downOpacity : Float = isDownloadingOn ? 1.0 : 0.0
        
        UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            self.sliderTime.hidden = isDownloadingOn
            self.labelTimeLeading.layer.opacity = playOpacity
            self.labelTimeTrailing.layer.opacity = playOpacity
            self.buttonPlayPause.layer.opacity = playOpacity
            self.labelDownloading.layer.opacity = downOpacity
            }) { (didComplete) -> Void in
                
        }
    }
    
    private func updateDownloadPercentDone(percent : Float) {
        let percentWhole = percent * 100.0
        let percentString = String(format: "%.0f%%", arguments: [percentWhole])
        self.labelDownloading.text = "\(percentString) complete"
    }
    
    func createPlayerWithData(data : NSData) {
        
        var error : NSError?
        self.player = AVAudioPlayer(data: data, error: &error)
        if error != nil {
            println("Error creating url \(url): \(error?.userInfo)")
        }
        else if let player = self.player {
            player.prepareToPlay()
        }
    }
    
    func playAtTime(time : NSTimeInterval) {

        if let player = self.player where time <= player.duration && time >= 0 {
            player.currentTime = time
            player.play()
            scheduleTimer()
        }
        else {
            assertionFailure("Something wrong with playAtTime method")
        }
    }
    
    func pause() {
        if let player = self.player where player.playing == true {
            player.pause()
            unscheduleCurrentTimer()
        }
    }
    
    // User Methods from View
    
    @IBAction func userPressedPlayPauseButton(sender: UIButton) {
        if let player = self.player {
            if player.playing {
                pause()
                // Update button to be play button
            }
            else {
                playAtTime(duration * Double(sliderTime.value) )
                // Update button to be pause button
            }
        }
        updateTimeUI()
    }
    
    @IBAction func userChangedSliderValue(slider: UISlider) {
        if let player = self.player {
            let time = duration * Double(slider.value)

            if player.playing {
                playAtTime(time)
            }
            else {
                player.currentTime = time
            }
        }
        else {
            self.sliderTime.setValue(0.0, animated: false)
        }
        updateTimeUI()
    }
    
    // Internal Methods
    
    private func updateTimeUI() {
        updateSliderLabels()
        updateSliderLocation()
    }
    
    private func updateSliderLabels() {
        if let player = self.player {
            labelTimeLeading.text = formattedTime(currentTime)
            labelTimeTrailing.text = formattedTime((duration-currentTime) * -1.0)
        }
        else {
            labelTimeTrailing.text = "-:--"
            labelTimeLeading.text = "-:--"
        }
    }
    
    private func updateSliderLocation() {
        sliderTime.value = Float( currentTime / duration )
    }
    
    func timerFired() {
        updateTimeUI()
        if (currentTime + 0.01) >= duration { // play time is over
            unscheduleCurrentTimer()
        }
    }
    
    /// Returns the formatted time string used on the slider
    private func formattedTime(time : NSTimeInterval) -> String {
        
        let signMultiplier = time < 0 ? -1.0 : 1.0
        let positiveTime = time * signMultiplier
        
        let minutes = Int( floor(positiveTime / 60) * signMultiplier )
        let seconds = Int( floor(positiveTime % 60) )
        
        if seconds < 10 { // add a zero
            return "\(minutes):0\(seconds)"
        }
        else {
            return "\(minutes):\(seconds)"
        }
    }
    
    private func scheduleTimer() {
        unscheduleCurrentTimer()
        self.timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "timerFired", userInfo: nil, repeats: true)
    }
    
    private func unscheduleCurrentTimer() {
        if let existingTimer = self.timer {
            existingTimer.invalidate()
            self.timer = nil
        }
    }
    
    // AVAudioPlayerDelegate Methods
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        if let error = error {
            assertionFailure("\(error.userInfo)")
        }
    }
    
}