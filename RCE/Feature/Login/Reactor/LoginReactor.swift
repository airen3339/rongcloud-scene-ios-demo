//
//  LoginReactor.swift
//  RCE
//
//  Created by 叶孤城 on 2021/4/21.
//

import Foundation
import ReactorKit

struct LoginReactorError: Error {
    let message: String
    let user: User
}

final class LoginReactor: Reactor {
    var initialState: State = State()
    enum Action {
        case login
        case inputPhoneNumber(String)
        case inputVerifyCode(String)
        case clickSendVerifyCode
    }
    
    enum Mutation {
        case setPhoneNumber(String)
        case setVerifyCode(String)
        case setError(ReactorError)
        case setSuccess(ReactorSuccess)
        case setCountdownRunning(Bool)
        case setCountdown(Int)
        case setRequestTitle(String)
        case resetCountdown
        case saveCurrentUser(User)
        case setLoginNetworkState(RCNetworkState)
    }
    
    struct State {
        var phoneNumber: String = ""
        var verifyCode: String = ""
        var error: ReactorError?
        var success: ReactorSuccess?
        var countdownRunning = false
        var countdown = 60
        var requestTitle = "发送验证码"
        var currentUser: User?
        var loginNetworkState: RCNetworkState = .idle
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .login:
            guard !currentState.phoneNumber.isEmpty else {
                return Observable<Mutation>.just(.setError(ReactorError("手机号不能为空")))
            }
            guard !currentState.verifyCode.isEmpty else {
                return Observable<Mutation>.just(.setError(ReactorError("验证码不能为空")))
            }
            isAppStoreAccount = currentState.phoneNumber == "18800000000"
            let begin = Observable<Mutation>.just(.setLoginNetworkState(.begin))
            let login = login()
            let end = Observable<Mutation>.just(.setLoginNetworkState(.idle))
            return .concat([begin, login, end])
        case let .inputPhoneNumber(number):
            return Observable<Mutation>.just(.setPhoneNumber(number))
        case let .inputVerifyCode(code):
            return Observable<Mutation>.just(.setVerifyCode(code))
        case .clickSendVerifyCode:
            guard !currentState.countdownRunning else {
                return .empty()
            }
            guard currentState.phoneNumber.count > 0 else {
                return .just(.setError(ReactorError("请先输入手机号")))
            }
            let codeSend = codeSendSuccess()
            return networkProvider.rx
                .request(.sendCode(mobile: currentState.phoneNumber))
                .map(SendCodeResponse.self)
                .asObservable()
                .flatMap({ (response) -> Observable<Mutation> in
                    if response.validate() {
                        let success = Observable<Mutation>.just(.setSuccess(ReactorSuccess("发送验证码成功")))
                        return .concat([success, codeSend])
                    } else {
                        return .just(.setError(ReactorError("发送验证码失败")))
                    }
                })
                .catchAndReturn(networkError())
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        case let .setPhoneNumber(number):
            state.phoneNumber = number
        case let .setVerifyCode(code):
            state.verifyCode = code
        case let .setError(error):
            state.error = error
        case let .setSuccess(success):
            state.success = success;
        case let .setCountdownRunning(isRunning):
            state.countdownRunning = isRunning
        case let .setCountdown(countdown):
            state.countdown = countdown
        case let .setRequestTitle(title):
            state.requestTitle = title
        case .resetCountdown:
            state.countdown = 60
        case let .saveCurrentUser(user):
            state.currentUser = user
            UserDefaults.standard.set(user: user)
            UserDefaults.standard.set(authorization: user.authorization)
            UserDefaults.standard.set(rongCloudToken: user.imToken)
        case let .setLoginNetworkState(next):
            state.loginNetworkState = next
        }
        return state
    }
    
    private func networkError() -> Mutation {
        return Mutation.setError(ReactorError("发送请求失败"))
    }
}

extension LoginReactor {
    private func codeSendSuccess() -> Observable<Mutation> {
        let setCountdownBegin = Observable<Mutation>.just(.setCountdownRunning(true))
        let timer = Observable<Int>.timer(.seconds(0), period: .seconds(1), scheduler: MainScheduler.instance).take(60).flatMap { [weak self](value) -> Observable<Mutation> in
            guard let self = self else { return .empty() }
            return Observable<Mutation>.just(.setCountdown(self.currentState.countdown - 1))
        }
        let setCountdownClose = Observable<Mutation>.just(.setCountdownRunning(false))
        let setTitle = Observable<Mutation>.just(.setRequestTitle("再次发送"))
        let reset = Observable<Mutation>.just(.resetCountdown)
        return .concat([setCountdownBegin, timer, setCountdownClose, setTitle, reset])
    }
    
    private func login() -> Observable<Mutation> {
        let api: RCNetworkAPI = .login(mobile: currentState.phoneNumber,
                                       code: currentState.verifyCode,
                                       userName: nil,
                                       portrait: nil,
                                       deviceId: UIDevice.current.identifierForVendor!.uuidString)
        return networkProvider.rx
            .request(api)
            .map(User.self, atKeyPath: "data", using: JSONDecoder(), failsOnEmptyData: true)
            .asObservable()
            .flatMapFirst({ user -> Observable<Result<User, ReactorError>> in
                return Observable<Result<User, ReactorError>>
                    .create { observer -> Disposable in
                        RCVoiceRoomEngine.sharedInstance().connect(withToken: user.imToken) {
                            debugPrint("connect token success")
                            DispatchQueue.main.async {
                                observer.onNext(.success(user))
                                observer.onCompleted()
                            }
                        } error: { code, msg in
                            debugPrint("connect token failed \(code) \(msg)")
                            DispatchQueue.main.async {
                                observer.onNext(.failure(ReactorError(msg)))
                                observer.onCompleted()
                            }
                        }
                        
                        return Disposables.create()
                    }
            })
            .flatMap { result -> Observable<Mutation> in
                switch result {
                case let .success(user):
                    return .concat([
                        .just(.saveCurrentUser(user)),
                        .just(.setLoginNetworkState(.success))
                    ])
                case let .failure(error):
                    return .just(.setLoginNetworkState(.failure(error)))
                }
            }
            .catchAndReturn(networkError())
    }
}
