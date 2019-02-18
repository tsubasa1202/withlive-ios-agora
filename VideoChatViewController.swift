//
//  VideoChatViewController.swift
//  Agora iOS Tutorial
//
//  Created by James Fang on 7/14/16.
//  Copyright © 2016 Agora.io. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit
import SVProgressHUD
import Alamofire
import SDWebImage

class VideoChatViewController: UIViewController {
    @IBOutlet weak var localVideo: UIView!
    @IBOutlet weak var remoteVideo: UIView!
    @IBOutlet weak var controlButtons: UIView!
    @IBOutlet weak var remoteVideoMutedIndicator: UIImageView!
    @IBOutlet weak var localVideoMutedBg: UIImageView!
    @IBOutlet weak var localVideoMutedIndicator: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var videoMuteButton: UIButton!
    var agoraKit: AgoraRtcEngineKit!
    var timer : Timer!
    var endTime: String?
    var channelName: String = ""
    var voiceOnly = false // APIから受け取るがデフォルトはfalse
    var isUser = true // APIから受け取るがデフォルトはtrue
    var castImage = appDelegate.dummyUseriamgeUrl
    var channelProfile = "broadcast"
    
    let AppID: String = "<APPID>"
    
    let retryMessage = "Wi-Fiをご利用の場合は4Gに切り替えて再入室してください。4Gをご利用の場合はWi-Fiに切り替えるか、モバイルデータ通信のオン・オフを切り替える、iPhoneの電源を入れ直すなどして再入室してください。"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // ナビゲーションを透明にする処理
        self.navigationController!.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationItem.hidesBackButton = true //戻るボタンを表示しなし
        
        // タイマーを作る
        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTimer(timer:)), userInfo: nil, repeats: true)
        print("channelName: \(channelName)")
        
        setupButtons()
        hideVideoMuted()
        initializeAgoraEngine()
        setupVideo()
        setupLocalVideo()
        joinChannel()
        
        if(!isUser && voiceOnly){
            agoraKit.muteLocalVideoStream(true)
            localVideo.isHidden = true
            localVideoMutedBg.isHidden = false
            localVideoMutedIndicator.isHidden = false
            videoMuteButton.isEnabled = false
        }else if(isUser && voiceOnly){
            remoteVideoMutedIndicator.contentMode = .scaleAspectFit
            remoteVideoMutedIndicator.sd_setImage(with: URL(string: castImage))
            
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /// 画面が閉じる直前に呼ばれる
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // タイマーを停止する
        if let workingTimer = timer{
            workingTimer.invalidate()
        }
        
    }
    
    // 現在時刻と終了時刻の差を返す
    func getSapnEndTimeFromNow() -> Double?{
        if let endTimeStr = self.endTime {
            
            let endTimeDate = Util.changeStringToDate(endTimeStr, "yyyy-MM-dd HH:mm:ss")
            let spanFromWow = endTimeDate.timeIntervalSinceNow
            return spanFromWow
        }else{
            return nil
        }
    }
    
    func updateTimer(timer: Timer) {
        if let count = getSapnEndTimeFromNow(){
            self.timeLabel.text = Util.convetSecondToTimeFormat(second: count)
            if(Int(count) <= 10){
                self.timeLabel.textColor = UIColor.red
                self.timeLabel.font = self.timeLabel.font.withSize(36)
            }
            
            if(Int(count) <= 0){
                // print("ゼロになりました")
                leaveChannel()
            }
        }
    }
    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: AppID, delegate: self)
        // print("channelProfile: \(self.channelProfile)")
        if(self.channelProfile == "broadcast"){
            // print("channelProfile is broadcast")
            agoraKit.setChannelProfile(.liveBroadcasting)
            agoraKit.setClientRole(.broadcaster)
            agoraKit.enableWebSdkInteroperability(true)
        }
    }

    func setupVideo() {
        agoraKit.enableVideo()  // Default mode is disableVideo
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360,
                                                                             frameRate: .fps15,
                                                                             bitrate: AgoraVideoBitrateStandard,
                                                                             orientationMode: .adaptative))
    }
    
    func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = localVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
    }
    
    func handleError(message: String){
        print(message)
        let parameters: Parameters = [
            "channel_name" : self.channelName,
            "message": message,
            ]
        Api.requestAPI(nil, .post, Api.liveLogiOS, parameters, self){_ in }
        let alert: UIAlertController = UIAlertController(title: "接続失敗", message: self.retryMessage, preferredStyle:  UIAlertControllerStyle.alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:{
            // ボタンが押された時の処理を書く
            (action: UIAlertAction!) -> Void in
            self.leaveChannel()
        })
        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    func joinChannel() {
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)

        let code = agoraKit.joinChannel(byToken: nil, channelId: self.channelName, info: nil, uid: 0, joinSuccess: nil)

        SVProgressHUD.dismiss()
        if code == 0 {
            UIApplication.shared.isIdleTimerDisabled = true // スリープにしない
        } else {
            DispatchQueue.main.async(execute: {
                self.handleError(message: "Join channel failed: \(code)")
            })
        }
    }
    
    @IBAction func didClickHangUpButton(_ sender: UIButton) {
        leaveChannel()
    }
    
    func leaveChannel() {
        agoraKit.leaveChannel(nil)
        hideControlButtons()
        UIApplication.shared.isIdleTimerDisabled = false // スリープにしないを解除
        remoteVideo.removeFromSuperview()
        localVideo.removeFromSuperview()
        self.navigationController?.popViewController(animated: true)
    }
    
    func setupButtons() {
        // perform(#selector(hideControlButtons), with:nil, afterDelay:8)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(VideoChatViewController.ViewTapped))
        view.addGestureRecognizer(tapGestureRecognizer)
        view.isUserInteractionEnabled = true
    }

    @objc func hideControlButtons() {
        controlButtons.isHidden = true
    }
    
    @objc func ViewTapped() {
        controlButtons.isHidden = !controlButtons.isHidden
        timeLabel.isHidden = !timeLabel.isHidden
        /*
        if (controlButtons.isHidden) {
            controlButtons.isHidden = false;
            perform(#selector(hideControlButtons), with:nil, afterDelay:8)
        }
         */
    }
    
    func resetHideButtonsTimer() {
        VideoChatViewController.cancelPreviousPerformRequests(withTarget: self)
        // perform(#selector(hideControlButtons), with:nil, afterDelay:8)
    }
    
    @IBAction func didClickMuteButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        agoraKit.muteLocalAudioStream(sender.isSelected)
        resetHideButtonsTimer()
    }
    
    @IBAction func didClickVideoMuteButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        agoraKit.muteLocalVideoStream(sender.isSelected)
        localVideo.isHidden = sender.isSelected
        localVideoMutedBg.isHidden = !sender.isSelected
        localVideoMutedIndicator.isHidden = !sender.isSelected
        resetHideButtonsTimer()
    }
    
    func hideVideoMuted() {
        remoteVideoMutedIndicator.isHidden = true
        localVideoMutedBg.isHidden = true
        localVideoMutedIndicator.isHidden = true
    }
    
    @IBAction func didClickSwitchCameraButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        agoraKit.switchCamera()
        resetHideButtonsTimer()
    }
}

extension VideoChatViewController: AgoraRtcEngineDelegate {
    
    func rtcEngineConnectionDidInterrupted(_ engine: AgoraRtcEngineKit) {
        handleError(message: "Connection Interrupted")
    }
    
    func rtcEngineConnectionDidLost(_ engine: AgoraRtcEngineKit) {
        handleError(message: "Connection Lost")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        handleError(message: "Other error errorCode: \(errorCode.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid:UInt, size:CGSize, elapsed:Int) {
        if (remoteVideo.isHidden) {
            remoteVideo.isHidden = false
        }
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = remoteVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupRemoteVideo(videoCanvas)
    }
    
    internal func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid:UInt, reason:AgoraUserOfflineReason) {
        self.remoteVideo.isHidden = true
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted:Bool, byUid:UInt) {
        remoteVideo.isHidden = muted
        remoteVideoMutedIndicator.isHidden = !muted
    }
}
