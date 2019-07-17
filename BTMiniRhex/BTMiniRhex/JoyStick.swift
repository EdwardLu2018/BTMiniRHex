//
//  JoyStick.swift
//  BTMiniRhex
//
//  Created by Edward on 7/16/19.
//  Copyright © 2019 Edward. All rights reserved.
//

import UIKit

class JoyStick: UIView {
    var delegate: RobotControl?
    var stick: UIView!
    
    var panGesture = UIPanGestureRecognizer()
    var absoluteCenter = CGPoint()
    var initialCenter = CGPoint()
    
    var x: CGFloat = 0
    var y: CGFloat = 0
    
    var radius: CGFloat!
    
    init(x: CGFloat, y: CGFloat, radius: CGFloat, stickRadius: CGFloat) {
        super.init(frame: CGRect(x: x, y: y, width: radius*2, height: radius*2))
        stick = UIView(frame: CGRect(x: frame.midX, y: frame.midY, width: stickRadius*2, height: stickRadius*2))
        stick.center = self.center
        
        absoluteCenter = self.center
        self.radius = radius
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
        
        stick.layer.cornerRadius = stick.frame.size.width / 2
        stick.clipsToBounds = true
        
        self.backgroundColor = UIColor.gray
        stick.backgroundColor = UIColor.darkGray
        
        self.addSubview(stick)
        panGesture.addTarget(self, action: #selector(handleStickPan))
        stick.addGestureRecognizer(panGesture)
    }
    
    @objc
    func handleStickPan(recognizer: UIPanGestureRecognizer) {
        guard panGesture.view != nil else { return }
        let translation = panGesture.translation(in: stick.superview)
        if panGesture.state == .began {
            initialCenter = stick.center
        }
        if panGesture.state != .cancelled {
            var newCenter = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            
            let angle = abs(atan(-(newCenter.y-absoluteCenter.y)/(newCenter.x-absoluteCenter.x)))
            
            newCenter.x = min(newCenter.x, radius*cos(angle)+absoluteCenter.x)
            newCenter.x = max(newCenter.x, absoluteCenter.x-radius*cos(angle))

            newCenter.y = max(newCenter.y, absoluteCenter.y-radius*sin(angle))
            newCenter.y = min(newCenter.y, (radius*sin(angle))+absoluteCenter.y)
            
            stick.center = newCenter
            x = (newCenter.x-absoluteCenter.x) / radius
            y = -(newCenter.y-absoluteCenter.y) / radius
            
            if abs(x) > abs(y) {
                if x > 0 {
                    print("right")
                    delegate?.right()
                }
                else if x < 0 {
                    print("left")
                    delegate?.left()
                }
            }
            else if abs(x) < abs(y) {
                if y > 0 {
                    print("forward")
                    delegate?.forward()
                }
                else if y < 0 {
                    print("backward")
                    delegate?.backward()
                }
            }
            else {
                print("stop")
                delegate?.stop()
            }
        }
        else {
            stick.center = initialCenter
        }
        if panGesture.state == .ended {
            stick.center = absoluteCenter
            print("stop")
            delegate?.stop()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
