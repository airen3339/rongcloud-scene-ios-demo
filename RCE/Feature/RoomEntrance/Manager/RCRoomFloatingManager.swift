//
//  RCRoomFloatingManager.swift
//  RCE
//
//  Created by shaoshuai on 2021/8/24.
//

import Foundation

class RCRoomFloatingManager {
    static let shared = RCRoomFloatingManager()
    
    private(set) var controller: RCRoomContainerViewController?
    private(set) lazy var floatingView: VoiceRoomFloatingView = {
        let instance = VoiceRoomFloatingView()
        instance.delegate = self
        return instance
    }()
    
    var currentRoomId: String? {
        return controller?.currentRoomId
    }
    
    var showing: Bool {
        /// 没有设置浮窗
        if controller == nil { return false }
        /// 浮窗没有显示
        return controller?.parent == nil
    }
    
    func show(_ controller: RCRoomContainerViewController) {
        self.controller = controller
        floatingView.frame = CGRect(x: UIScreen.main.bounds.width - 17 - 66,
                                    y: UIScreen.main.bounds.height - 194,
                                    width: 66,
                                    height: 66)
        floatingView.updateAvatar(url: URL(string: controller.currentRoom.themePictureUrl))
        miniScaleAnimation(controller)
        UIApplication.shared.keyWindow()?.addSubview(floatingView)
    }
    
    private func miniScaleAnimation(_ controller: UIViewController) {
        let image = UIGraphicsImageRenderer(size: controller.view.bounds.size)
            .image { renderer in
                controller.view.layer.render(in: renderer.cgContext)
            }
        let imageView = UIImageView(image: image)
        UIApplication.shared.keyWindow()?.addSubview(imageView)
        
        let center = floatingView.center
        let radius = floatingView.bounds.width * 0.5
        let fromPath = UIBezierPath(arcCenter: center,
                                    radius: UIScreen.main.bounds.size.height,
                                    startAngle: 0,
                                    endAngle: .pi * 2,
                                    clockwise: false)
        let toPath = UIBezierPath(arcCenter: center,
                                  radius: radius,
                                  startAngle: 0,
                                  endAngle: .pi * 2,
                                  clockwise: false)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = fromPath.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        imageView.layer.mask = shapeLayer
        
        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = fromPath.cgPath
        pathAnimation.toValue = toPath.cgPath
        pathAnimation.duration = 0.37
        pathAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pathAnimation.fillMode = .forwards
        pathAnimation.isRemovedOnCompletion = false
        shapeLayer.add(pathAnimation, forKey: "path_circle")
        
        UIView.animate(withDuration: 0.1, delay: 0.37, options: .curveLinear) {
            imageView.alpha = 0
        } completion: { _ in
            imageView.removeFromSuperview()
            shapeLayer.removeAllAnimations()
        }
    }
    
    func hide() {
        floatingView.removeFromSuperview()
        controller = nil
    }
    
    func setSpeakingState(isSpeaking: Bool, seatInfo: RCVoiceSeatInfo?) {
        let isMuted = seatInfo?.isMuted ?? true
        guard isSpeaking, seatInfo?.status == .using, !isMuted else {
            floatingView.radarView.stop()
            return
        }
        if floatingView.radarView.isPulsating {
            return
        } else {
            floatingView.radarView.start()
        }
    }
}

extension RCRoomFloatingManager: VoiceRoomFloatingViewDelegate {
    func floatingViewDidClick() {
        defer { hide() }
        guard
            let vc = UIApplication.shared.topMostViewController(),
            let nav = vc as? UINavigationController,
            let controller = controller
        else { return }
        nav.pushViewController(controller, animated: true)
    }
}
