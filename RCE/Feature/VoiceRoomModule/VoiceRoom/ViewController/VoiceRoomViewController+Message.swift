//
//  VoiceRoomViewController+Message.swift
//  RCE
//
//  Created by shaoshuai on 2021/6/22.
//

import SVProgressHUD
import RCRTCAudio

fileprivate var RCVRecordAlertRef = 1

extension VoiceRoomViewController {
    @_dynamicReplacement(for: setupModules)
    private func setupChatModule() {
        setupModules()
        toolBarView.add(message: self, action: #selector(handleMessageButtonClick))
        toolBarView.recordButton.recordStateChanged = recordStateChanged(_:)
        toolBarView.recordButton.recordDidSuccess = recordDidSuccess(_:)
    }
    
    @_dynamicReplacement(for: handleReceivedMessage(_:))
    private func chat_handleReceivedMessage(_ message :RCMessage) {
        handleReceivedMessage(message)
        guard message.conversationType == .ConversationType_PRIVATE else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.toolBarView.refreshUnreadMessageCount()
        }
    }
    
    private var recordAlertController: RCVRVoiceAlertViewController {
        get {
            var controller = objc_getAssociatedObject(self, &RCVRecordAlertRef)
            if controller == nil {
                controller = RCVRVoiceAlertViewController()
                self.recordAlertController = controller as! RCVRVoiceAlertViewController
            }
             return controller as! RCVRVoiceAlertViewController
        }
        set {
            objc_setAssociatedObject(self, &RCVRecordAlertRef, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @objc private func handleMessageButtonClick() {
        navigator(.messagelist)
    }
    
    private func recordStateChanged(_ state: RCVRVoiceButtonState) {
        recordAlertController.update(state)
        switch state {
        case .none: ()
        case .begin, .lack:
            if presentedViewController == recordAlertController { break }
            recordAlertController.modalTransitionStyle = .crossDissolve
            recordAlertController.modalPresentationStyle = .overFullScreen
            present(recordAlertController, animated: true, completion: nil)
        case .recording: ()
        case .outArea: ()
        case .cancel, .end:
            recordAlertController.dismiss(animated: true, completion: nil)
        }
    }
    
    private func recordDidSuccess(_ result: (url: URL, time: TimeInterval)?) {
        guard let result = result else { return }
        let url = result.url
        let time = UInt(result.time)
        if time < 1 {
            return SVProgressHUD.showError(withStatus: "录音时间太短")
        }
        guard let data = try? Data(contentsOf: url) else {
            return SVProgressHUD.showError(withStatus: "录音文件错误")
        }
        let ext = url.pathExtension
        networkProvider.request(.uploadAudio(data: data, extension: ext)) { [weak self] result in
            switch result {
            case let .success(response):
                guard
                    let model = try? JSONDecoder().decode(UploadfileResponse.self, from: response.data)
                else { return }
                let urlString = Environment.current.url.absoluteString + "/file/show?path=" + model.data
                self?.sendMessage(urlString, time: time, url: url)
            case let .failure(error):
                print(error)
            }
        }

    }
    
    private func sendMessage(_ voice: String, time: UInt, url: URL) {
        let roomId = voiceRoomInfo.roomId
        UserInfoDownloaded.shared.fetchUserInfo(userId: Environment.currentUserId) { user in
            let message = RCVRVoiceMessage()
            message.userId = user.userId
            message.userName = user.userName
            message.path = voice
            message.duration = time
            RCChatroomMessageCenter.sendChatMessage(roomId, content: message) { [weak self] mId in
                self?.messageView.add(message)
                RCRTCAudioRecorder.shared.remove(url)
            } error: { eCode, mId in
                RCRTCAudioRecorder.shared.remove(url)
            }
        }
    }
}
