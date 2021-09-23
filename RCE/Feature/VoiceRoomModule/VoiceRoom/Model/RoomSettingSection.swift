//
//  RoomSettingView.swift
//  RCE
//
//  Created by 叶孤城 on 2021/5/6.
//

import UIKit

enum ConnectMicState {
    case request
    case waiting
    case connecting
    
    var image: UIImage? {
        switch self {
        case .request:
            return R.image.connect_mic_state_none()
        case .waiting:
            return R.image.connect_mic_state_waiting()
        case .connecting:
            return R.image.connect_mic_state_connecting()
        }
    }
}

enum VoiceRoomPKRole {
    case inviter
    case invitee
    case audience
}

struct VoiceRoomPKInfo {
    let inviterId: String
    let inviteeId: String
    let inviterRoomId: String
    let inviteeRoomId: String
    
    func currentUserRole() -> VoiceRoomPKRole {
        if Environment.currentUserId == inviterId {
            return .inviter
        }
        if Environment.currentUserId == inviteeId {
            return .invitee
        }
        return .audience
    }
    
//    func isInviter() -> Bool {
//        return inviterId == UserDefaults.standard.loginUser()?.userId
//    }
//
//    func pkId() -> String {
//        return isInviter() ? inviteeId : inviterId
//    }
//
//    func isUserPKAttender(userId: String?) -> Bool {
//        guard let userId = userId else {
//            return false
//        }
//        return userId == inviterId || userId == inviteeId
//    }
}

struct RoomSettingState {
    var isMutePKUser = false {
        didSet {
            mutePKStateChanged?(isMutePKUser)
        }
    }
    var lastInviteUserId: String?
    var lastInviteRoomId: String?
    var isPrivate = false
    var isMuteAll = false
    var isLockAll = false
    var isSilence = false
    var isCloseSelfMic = false
    var isFreeEnterSeat = false
    var isSeatModeLess = false
    var isEnterSeatWaiting = false
    var currentPKInfo: VoiceRoomPKInfo?
    var connectState: ConnectMicState = .request {
        didSet {
            connectStateChanged?(connectState)
        }
    }
    var pkConnectState: ConnectMicState = .request {
        didSet {
            switch pkConnectState {
            case .request:
                currentPKInfo = nil
                lastInviteRoomId = nil
                lastInviteUserId = nil
            case .connecting:
                lastInviteRoomId = nil
                lastInviteUserId = nil
            case .waiting:
                currentPKInfo = nil
            }
            pkConnectStateChanged?(pkConnectState)
        }
    }
    var connectStateChanged:((ConnectMicState) -> Void)?
    var pkConnectStateChanged:((ConnectMicState) -> Void)?
    var mutePKStateChanged:((Bool) -> Void)?
    
    init(room: VoiceRoom) {
        isPrivate = room.isPrivate == 1
    }
    
    mutating func update(from state: VoiceRoomState) {
        isMuteAll = state.applyAllLockMic
        isLockAll = state.applyAllLockSeat
        isFreeEnterSeat = !state.applyOnMic
        isSilence = state.setMute
        isSeatModeLess = state.setSeatNumber < 9
    }
    
    func settinglist() -> [RoomSettingItem] {
        return [.lockRoom(isPrivate),
                .roomTitle,
                .notice,
                .roomBackground,
                .isFreeEnterSeat(isFreeEnterSeat),
                .muteAllSeat(isMuteAll),
                .lockAllSeat(isLockAll),
                .muteSelf(isSilence),
                .lessSeatMode(isSeatModeLess),
                .forbidden,
                .music]
    }
    
    func isPKOngoing() -> Bool {
        return currentPKInfo != nil
    }
}

enum RoomSettingItem {
    case lockRoom(Bool)
    case muteAllSeat(Bool)
    case lockAllSeat(Bool)
    case muteSelf(Bool)
    case music
    case isFreeEnterSeat(Bool)
    case roomTitle
    case roomBackground
    case lessSeatMode(Bool)
    case forbidden
    case suspend(Bool)
    case notice
}

extension RoomSettingItem {
    var title: String {
        switch self {
        case let .lockRoom(isLock):
            return isLock ? "房间解锁" : "房间上锁"
        case let .muteAllSeat(isMute):
            return isMute ? "解锁全麦" : "全麦锁麦"
        case let .lockAllSeat(isLock):
            return isLock ? "解锁全座" : "全麦锁座"
        case let .muteSelf(isMute):
            return isMute ? "取消静音" : "静音"
        case let .isFreeEnterSeat(isFree):
            return isFree ? "申请上麦" : "自由上麦"
        case .roomTitle:
            return "房间标题"
        case .roomBackground:
            return "房间背景"
        case let .lessSeatMode(isLess):
            return (isLess ? "设置8个座位" : "设置4个座位")
        case .music:
            return "音乐"
        case .forbidden:
            return "屏蔽词"
        case let .suspend(value):
            return value ? "继续直播" : "暂停直播"
        case .notice:
            return "房间公告"
        }
    }
    
    var image: UIImage? {
        switch self {
        case let .lockRoom(isLock):
            return isLock ? R.image.voiceroom_setting_unlockroom() : R.image.voiceroom_setting_lockroom()
        case let .muteAllSeat(isMute):
            return isMute ? R.image.voiceroom_setting_unmuteall() : R.image.voiceroom_setting_muteall()
        case let .lockAllSeat(isLock):
            return isLock ? R.image.voiceroom_setting_unlockallseat() : R.image.voiceroom_setting_lockallseat()
        case let .muteSelf(isMute):
            return isMute ? R.image.voiceroom_setting_unmute() : R.image.voiceroom_setting_mute()
        case .music:
            return R.image.voiceroom_setting_music()
        case let .isFreeEnterSeat(isFree):
            return isFree ? R.image.voiceroom_setting_freemode() : R.image.voiceroom_setting_applymode()
        case .roomTitle:
            return R.image.voiceroom_setting_title()
        case .roomBackground:
            return R.image.voiceroom_setting_background()
        case let .lessSeatMode(isLess):
            return isLess ? R.image.voiceroom_setting_addseat() : R.image.voiceroom_setting_minusseat()
        case .forbidden:
            return R.image.forbidden_text_icon()
        case let .suspend(value):
            return value ? R.image.voiceroom_setting_suspend() : R.image.voiceroom_setting_suspend()
        case .notice:
            return R.image.voiceroom_setting_notice()
        }
    }
}
