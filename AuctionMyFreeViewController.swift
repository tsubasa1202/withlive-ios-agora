//
//  ReservationViewController.swift
//  ArtisTalk
//
//  Created by Tsubasa Oshima on 2018/03/19.
//  Copyright © 2018年 Tsubasa Oshima. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import UserNotifications
import SVProgressHUD
import AVFoundation
import AgoraRtcEngineKit
import Reachability

class AuctionMyFreeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource  {
    
    @IBOutlet weak var talksListTable: UITableView!
    var talks: JSON?
    let dateFormat = "yyyy-MM-dd HH:mm:ss"
    var agoraKit: AgoraRtcEngineKit!
    let AppID: String = "<APPID>"
    var agoraQuorityCheckCount = 0
    var inProgressNetworkTest = false
    var liveInfo: JSON!
    var acceptNetworkQuality: Int = 2
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "LIVE予定"
        SVProgressHUD.show()
        self.navigationController?.navigationBar.barTintColor = UIColor.white
        self.navigationController?.navigationBar.tintColor = UIColor.black
        self.view.backgroundColor = UIColor.groupTableViewBackground
        self.talksListTable.backgroundColor = UIColor.groupTableViewBackground
        self.talksListTable.layer.masksToBounds = false // セルの境界からはみ出ているものを見えなくするのをOFF
        self.talksListTable.showsVerticalScrollIndicator = false //スクロールバーを表示しない
        self.talksListTable.tableFooterView = UIView(frame: .zero) //余計な罫線を非表示
        self.talksListTable.delegate = self
        self.talksListTable.dataSource = self
        self.talksListTable.estimatedRowHeight = 150
        self.talksListTable.rowHeight = UITableViewAutomaticDimension
        
         self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named : "radio_tower"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(self.networkTest))
        
        //self.title = Util.chageDateFormat(date!, "yyyyMMdd", "yyyy年M月d日")
        self.talksListTable.register(UINib(nibName: "AuctionBuyCell", bundle: nil), forCellReuseIdentifier: "AuctionBuyCell")
        self.initializeAgoraEngine()
        self.load()
    }
    
    func permissionCheck() -> Bool{
        
        let statusAudio = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
        let statusVideo = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        if  statusVideo != .authorized || statusAudio != .authorized  {
            let mainStoryboard = UIStoryboard(name: "User", bundle: nil)
            let permissionVC = mainStoryboard.instantiateViewController(withIdentifier: "userPermission")
            self.present(permissionVC, animated: true)
            return false
        }
        
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 透明にしたナビゲーションを元に戻す処理
        self.navigationController!.navigationBar.setBackgroundImage(nil, for: .default)
        self.navigationController!.navigationBar.shadowImage = nil
        self.navigationController?.navigationBar.barTintColor = UIColor.white
        self.initializeAgoraEngine() // 入室して戻ってきた時のために再度初期化が必要。これがないと戻ってきた時にNetworkTestができない
        self.reload()
    }
    
    func load(){
        appDelegate.getCurrentUserIdToken(self){ token in
            let headers : Dictionary<String, String> = ["Authorization": token]
            Api.requestAPI(headers, .get, Api.talkMine, nil, self){ response in
                self.talks = response["result"]
                self.acceptNetworkQuality = response["accept_network_quality"].int!
                self.talksListTable.reloadData()
                SVProgressHUD.dismiss()
                
                if(self.talks?.count == 0){
                    if(self.talksListTable != nil){
                        Util.makeTableViewBackgroundWhenContentsNone(self.talksListTable, text: "LIVE予定はまだありません。\nLIVEを購入するとこちらに表示されます。")
                    }
                }else{
                    if(self.permissionCheck()){
                        // ど初回はいきなりビデオ通話に入らないと仮定（配信者側へは説明が初回、ユーザーは予約後の確認が最初のはず）
                        self.networkTest()
                    }
                    self.talksListTable?.backgroundView = nil
                }
            }
        }
    }
    
    func reload(){
        appDelegate.getCurrentUserIdToken(self){ token in
            let headers : Dictionary<String, String> = ["Authorization": token]
            Api.requestAPI(headers, .get, Api.talkMine, nil, self){ response in
                self.talks = response["result"]
                self.talksListTable.reloadData()

                if(self.talks?.count == 0){
                    if(self.talksListTable != nil){
                        Util.makeTableViewBackgroundWhenContentsNone(self.talksListTable, text: "LIVE予定はまだありません。\nLIVEを購入するとこちらに表示されます。")
                    }
                }else{
                    self.talksListTable?.backgroundView = nil
                }
            }
        }
    }
    
    func networkTest() {
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.show(withStatus: "ネットワーク環境を確認中")
        self.inProgressNetworkTest = true
        self.agoraQuorityCheckCount = 0
        self.agoraKit.enableLastmileTest()
    }
    
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10.0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10.0
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.clear // 透明にすることでスペースとする
    }
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.clear // 透明にすることでスペースとする
    }
    
    /*
     セクションの数を返す.
     */
    func numberOfSections(in tableView: UITableView) -> Int {
        if let count = talks?.count{
            return count
        }else{
            return 0
        }
    }
    
    /*
     セルの数を返す（1セクションに1セル）
     */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.talks != nil){
            return 1
        }else{
            return 0
        }
    }
    
    @objc func reserveButton(sender : UIButton) {
        print("sender.tag: \(sender.tag)")
        self.tappedAction(sender.tag)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //let cell = tableView.dequeueReusableCell(withIdentifier: "talkListCell") as! CustomTableViewCell
        let cell = tableView.dequeueReusableCell(withIdentifier: "AuctionBuyCell") as! AuctionBuyCell
        cell.voiceOnlyIcon.isHidden = !(self.talks![indexPath.section]["voice_only"].bool!)
        var castName = self.talks![indexPath.section]["cast_name"].string!
        
        if let group = self.talks![indexPath.section]["group"].string, !group.isEmpty {
            castName = group + "\n" + castName
        }
        
        //print("castName: \(castName)")
        cell.castName.text = castName
        let startTime = Util.chageDateFormat(self.talks![indexPath.section]["start_time"].string!, dateFormat,"M/d HH:mm")
        let endTimeDate = Util.changeStringToDate(self.talks![indexPath.section]["end_time"].string!, dateFormat)
        
        //print("now: \(Date())")
        //print("endTimeDate: \(endTimeDate)")
        if(Date() > endTimeDate){
            cell.overBlackImageView.isHidden = false
        }else{
            cell.overBlackImageView.isHidden = true
        }
        
        cell.startTimeLabel.text = startTime + "〜 " + self.talks![indexPath.section]["duration"].string! + "分間"
        cell.overBlackImageView.layer.cornerRadius = 8.0;
        cell.overBlackImageView.clipsToBounds = true
        cell.layer.cornerRadius = 8.0;
        cell.clipsToBounds = true
        cell.layer.masksToBounds = false // セルの境界からはみ出ているものを見えなくするのをOFF
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOpacity = 0.2 // 透明度（低いほど等見え）
        cell.layer.shadowOffset = CGSize(width: 0, height: 10) // 距離
        cell.layer.shadowRadius = 5 // ぼかし量（10くらいが結構ボケる）
        
        cell.backgroundImage.layer.cornerRadius = 8.0;
        cell.backgroundImage.clipsToBounds = true
        
        //キャストの画像のかげの部分
        cell.imageViewShadow.clipsToBounds = false
        cell.imageViewShadow.layer.shadowColor = UIColor.black.cgColor
        cell.imageViewShadow.layer.shadowOpacity = 0.5
        cell.imageViewShadow.layer.shadowOffset = CGSize(width: 5, height: 5)
        cell.imageViewShadow.layer.shadowRadius = 5.0
        cell.imageViewShadow.layer.shadowPath = UIBezierPath(roundedRect: cell.imageViewShadow.bounds, cornerRadius:
            cell.imageViewShadow.frame.size.width * 0.5).cgPath
        
        let castImageView = UIImageView(frame: cell.imageViewShadow.bounds)
        if let imageUrl = self.talks![indexPath.section]["image"].string{
            castImageView.sd_setImage(with: URL(string: imageUrl))
        }else{
            castImageView.sd_setImage(with: URL(string: appDelegate.dummyUseriamgeUrl))
        }
        
        castImageView.clipsToBounds = true
        
        castImageView.layer.borderWidth = 2.0
        castImageView.layer.borderColor = UIColor.white.cgColor
        castImageView.layer.cornerRadius =  castImageView.frame.size.width * 0.5;
        cell.imageViewShadow.addSubview(castImageView)
        
        cell.reserveButton.layer.borderWidth = 1.0
        cell.reserveButton.layer.borderColor = UIColor.white.cgColor
        cell.reserveButton.cornerRadius = cell.reserveButton.frame.size.height * 0.5;
        cell.reserveButton.layer.shadowColor = UIColor.black.cgColor
        cell.reserveButton.layer.shadowOpacity = 0.5 // 透明度
        cell.reserveButton.layer.shadowOffset = CGSize(width: 5, height: 5) // 距離
        cell.reserveButton.layer.shadowRadius = 5 // ぼかし量
        cell.reserveButton.clipsToBounds = true
        
        cell.reserveButton.addTarget(self,
                                     action: #selector(self.reserveButton(sender:)),
                                     for: .touchUpInside)
        cell.reserveButton.tag = indexPath.section
        
        cell.componentView.isOpaque = false // 不透明を false
        cell.componentView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0) //完全透過
        
        
        return cell
    }
    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: AppID, delegate: self)
    }
    // セルをタップした時の処理
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tappedAction(indexPath.section)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    func tappedAction(_ cellNum: Int){
        
        let dateFormat = "yyyy-MM-dd HH:mm:ss"
        let startTimeDate = Util.changeStringToDate((self.talks?[cellNum]["start_time"].string)!, dateFormat)
        let canEnterRoomTime = Date(timeInterval: -5 * 60, since: startTimeDate) // 開始時刻の5分前から入室可能
        let endTimeDate = Util.changeStringToDate((self.talks?[cellNum]["end_time"].string)!, dateFormat)
        
        let now = Date();
        
        // テストのときは入室の時間制限を解除
        #if DEV
        #elseif STG
        #else
        if(now < canEnterRoomTime){
            Util.viewAlertNoMove(title: "お知らせ", message: "開始時間の5分前から入室可能です。", vc: self)
            return
        }else if(now > endTimeDate){
            Util.viewAlertNoMove(title: "お知らせ", message: "このLIVEは終了しています。", vc: self)
            return
        }
        #endif
        
        if !permissionCheck(){
            return
        }
        
        //タップしたらユーザーからの操作を無効にする
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.show()
        // sessionIdとtokenの取得
        let status = UserDefaults.standard.object(forKey: "status") as! String
        let parameters: Parameters = [
            "status": status
        ]
        appDelegate.getCurrentUserIdToken(self){ token in
            let headers : Dictionary<String, String> = ["Authorization": token]
            let liveId = self.talks?[cellNum]["auction_id"].string!
            Api.requestAPI(headers, .get, "\(Api.talkVideo)/\(liveId!)", parameters, self){ response in
                
                if(response["result"]["video_mode"].string! == "opentok"){
                    let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let videoCallViewController: TokVideoCallViewController = mainStoryboard.instantiateViewController(withIdentifier: "tokVideoCall") as! TokVideoCallViewController
                    videoCallViewController.endTime = response["result"]["end_time"].string!
                    videoCallViewController.kSessionId = response["result"]["session_id"].string!
                    videoCallViewController.kToken = response["result"]["token"].string!
                    videoCallViewController.voiceOnly = response["result"]["voice_only"].bool!
                    videoCallViewController.isUser = response["result"]["is_user"].bool!
                    videoCallViewController.castName = response["result"]["cast_name"].string!
                    
                    if let castImage = response["result"]["cast_image"].string{
                        videoCallViewController.castImage = castImage
                    }else{
                        videoCallViewController.castImage = appDelegate.dummyUseriamgeUrl
                    }
                    self.navigationController?.pushViewController(videoCallViewController, animated: true)
                    
                }else{
                    SVProgressHUD.show(withStatus: "ネットワーク環境を確認中")
                    self.liveInfo = response
                    self.initializeAgoraEngine()
                    self.agoraQuorityCheckCount = 0
                    print("begintest_first")
                    self.agoraKit.enableLastmileTest()
                    
                }
            }
        }
        
    }
    
    func showNetworkAlert(videoViewController: VideoChatViewController?){
        var warnMessage = "ネットワーク環境が不安定です。正常に接続できない可能性があります。Wi-Fiをご利用中の場合は4Gに切り替えてください。4Gをご利用中の場合はWi-Fiに切り替えるかiPhoneの電源を入れ直してください。"
        if let reachability = Reachability() {
            switch(reachability.connection){
            case.wifi:
                warnMessage = "ネットワーク環境が不安定です。正常に接続できない可能性があります。別のWi-Fiに接続するか、4Gに切り替えて再度お試しください。"
            case.cellular:
                warnMessage = "ネットワーク環境が不安定です。正常に接続できない可能性があります。Wi-Fiに切り替えるか、モバイルデータ通信のオン・オフを切り替える、iPhoneの電源を入れ直すなどして再度お試しください。"
            case .none:
                warnMessage = "ネットワークがオフラインです。インターネットに接続してください。"
            }
        }
        
        let alert: UIAlertController = UIAlertController(title: "警告", message: warnMessage, preferredStyle:  UIAlertControllerStyle.alert)
        
        var lastMessage = "OK"
        if let videoVC = videoViewController {
            lastMessage = "キャンセル"
            let enterAction: UIAlertAction = UIAlertAction(title: "入室（非推奨）", style: UIAlertActionStyle.default, handler:{
                // ボタンが押された時の処理を書く
                (action: UIAlertAction!) -> Void in
                self.navigationController?.pushViewController(videoVC, animated: true)
            })
            alert.addAction(enterAction)
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: lastMessage, style: UIAlertActionStyle.default, handler:{
            // ボタンが押された時の処理を書く
            (action: UIAlertAction!) -> Void in
        })
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
extension AuctionMyFreeViewController: AgoraRtcEngineDelegate {
    
    // Register the callback.
    func rtcEngine(_ engine: AgoraRtcEngineKit, lastmileQuality quality: AgoraNetworkQuality) {
        if(self.inProgressNetworkTest){
            agoraQuorityCheckCount = agoraQuorityCheckCount + 1
            // print("lastmileQuality: \(quality.rawValue)")
            // print("agoraQuorityCheckCount: \(agoraQuorityCheckCount)")
            
            if(quality.rawValue > 0 || agoraQuorityCheckCount > 4 ){
                
                var parameters: Parameters = [
                    "quality": quality.rawValue,
                    "agoraQuorityCheckCount": agoraQuorityCheckCount
                ]
                
                if let reachability = Reachability() {
                    parameters["network"] = reachability.connection
                }
                Api.requestAPI(nil, .post, Api.liveLogNetwork, parameters, self){_ in }
                
                agoraKit.disableLastmileTest()
                self.inProgressNetworkTest = false
                SVProgressHUD.dismiss()
                
                if( 1 <= quality.rawValue && quality.rawValue <= self.acceptNetworkQuality){
                    var message = ""
                    switch quality.rawValue {
                    case 1:
                        message = "大変良好"
                    case 2:
                        message = "良好"
                    case 3:
                        message = "やや悪い"
                    case 4:
                        message = "悪い"
                    case 5:
                        message = "とても悪い"
                    case 6:
                        message = "極めて悪い"
                    default:
                       message = "不明"
                    }
                    Util.viewAlertNoMove(title: "結果", message: "ネットワークは【\(message)】です。\nビデオ通話に接続可能です。", vc: self)
                }else{
                    self.showNetworkAlert(videoViewController: nil)
                }
            }
            return
        }
        
        // 入室時に使われる
        agoraQuorityCheckCount = agoraQuorityCheckCount + 1
        // print("lastmileQuality: \(quality.rawValue)")
        // print("agoraQuorityCheckCount: \(agoraQuorityCheckCount)")
        if(quality.rawValue > 0 || agoraQuorityCheckCount > 4 ){
            agoraKit.disableLastmileTest()
            
            var parameters: Parameters = [
                "channelName": self.liveInfo["result"]["channel"].string!,
                "quality": quality.rawValue,
                "agoraQuorityCheckCount": agoraQuorityCheckCount
            ]
            if let reachability = Reachability() {
                parameters["network"] = reachability.connection
            }
            Api.requestAPI(nil, .post, Api.liveLogNetwork, parameters, self){_ in }
            
            let videoStoryboard = UIStoryboard(name: "Video", bundle: nil)
            let videoViewController: VideoChatViewController = videoStoryboard.instantiateViewController(withIdentifier: "videoChat") as! VideoChatViewController
            videoViewController.channelName = self.liveInfo["result"]["channel"].string!
            videoViewController.voiceOnly = self.liveInfo["result"]["voice_only"].bool!
            videoViewController.isUser = self.liveInfo["result"]["is_user"].bool!
            videoViewController.endTime = self.liveInfo["result"]["end_time"].string!
            videoViewController.channelProfile = self.liveInfo["result"]["channel_profile"].string!
            if let castImage = self.liveInfo["result"]["cast_image"].string{
                videoViewController.castImage = castImage
            }else{
                videoViewController.castImage = appDelegate.dummyUseriamgeUrl
            }

            if( 1 <= quality.rawValue && quality.rawValue <= self.acceptNetworkQuality){
                self.navigationController?.pushViewController(videoViewController, animated: true)
            }else{
                SVProgressHUD.dismiss()
                self.showNetworkAlert(videoViewController: videoViewController)
                
            }
        }
        
    }
}


