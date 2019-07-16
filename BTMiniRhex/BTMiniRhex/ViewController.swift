//
//  ViewController.swift
//  BTTest-MiniRhex
//
//  Created by Edward on 6/26/19.
//  Copyright © 2019 Edward. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol CBControl {
    var peripherals: [CBPeripheral] { get set }
    var robotPeripheral: CBPeripheral! { get set }
    func scan()
}

class ViewController: UIViewController, CBControl {
    
    var centralManager: CBCentralManager!
    var robotPeripheral: CBPeripheral!
    var peripherals = [CBPeripheral]()
    var peripheralIndex: Int = 0
    
    @IBOutlet weak var forward: UIButton!
    @IBOutlet weak var right: UIButton!
    @IBOutlet weak var backward: UIButton!
    @IBOutlet weak var left: UIButton!
    @IBOutlet weak var stop: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    let kUartServiceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    let kUartTxCharacteristicUUID = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    let kUartRxCharacteristicUUID = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
    var targetService: CBService?
    var TxCharacteristic: CBCharacteristic?
    var RxCharacteristic: CBCharacteristic?
    
    enum PeripheralVCState {
        case expanded
        case collapsed
    }
    
    var peripheralVCVisible = false
    
    func nextPeripheralVCState() -> PeripheralVCState {
        return peripheralVCVisible ? .collapsed : .expanded
    }
    
    var peripheralViewController: PeripheralViewController!
    var visualEffectView: UIVisualEffectView!
    
    let peripheralVCHeight: CGFloat = 600
    let peripheralVCHandleArea: CGFloat = 50
    
    var runningAnimations = [UIViewPropertyAnimator]()
    var animationProgressWhenInterrupted: CGFloat = 0
    
    var panGestureRecognizer = UIPanGestureRecognizer()
    
    var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        statusLabel.text = "Scanning for MiniRHexs..."
        
        setUpSongViewController()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setupLoading()
    }
    
    func setupLoading() {
        loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: self.view.center.x - 25, y: disconnectButton.center.y + 20, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.gray
        loadingIndicator.startAnimating()
        
        view.addSubview(loadingIndicator)
        view.sendSubviewToBack(loadingIndicator)
    }
    
    func setUpSongViewController() {
        visualEffectView = UIVisualEffectView()
        visualEffectView.frame = self.view.frame
        self.view.addSubview(visualEffectView)
        self.view.sendSubviewToBack(visualEffectView)
        
        if let peripheralViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "peripheralView") as? PeripheralViewController {
            self.peripheralViewController = peripheralViewController
            self.addChild(peripheralViewController)
            self.view.addSubview(peripheralViewController.view)
            
            peripheralViewController.view.frame = CGRect(x: 0.0, y: self.view.frame.height - peripheralVCHandleArea, width: self.view.bounds.width, height: peripheralVCHeight)
            
            peripheralViewController.view.clipsToBounds = true
            peripheralViewController.delegate = self
            
            panGestureRecognizer = UIPanGestureRecognizer()
            panGestureRecognizer.addTarget(self, action: #selector(handleDataPan))
            peripheralViewController.handleArea.addGestureRecognizer(panGestureRecognizer)
        }
    }
    
    @objc
    func handleDataPan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startTransition(state: nextPeripheralVCState(), duration: 1.0)
        case .changed:
            let translation = recognizer.translation(in: self.peripheralViewController.handleArea)
            var fractionComplete = translation.y / peripheralVCHeight
            fractionComplete = peripheralVCVisible ? fractionComplete : -fractionComplete
            updateTransition(fractionCompleted: fractionComplete)
        case .ended:
            continueTransition()
        default:
            break
        }
    }
    
    func animateTransitionIfNeeded(state: PeripheralVCState, duration: TimeInterval) {
        if runningAnimations.isEmpty {
            let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.85) {
                switch state {
                case .expanded:
                    self.peripheralViewController.view.frame.origin.y = self.view.frame.height - self.peripheralVCHeight
                case .collapsed:
                    self.peripheralViewController.view.frame.origin.y = self.view.frame.height - self.peripheralVCHandleArea
                }
            }
            frameAnimator.addCompletion { _ in
                self.peripheralVCVisible = !self.peripheralVCVisible
                self.runningAnimations.removeAll()
            }
            frameAnimator.startAnimation()
            runningAnimations.append(frameAnimator)
            
            let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {
                switch state {
                case .expanded:
                    self.peripheralViewController.view.layer.cornerRadius = 15
                case .collapsed:
                    self.peripheralViewController.view.layer.cornerRadius = 7
                }
            }
            cornerRadiusAnimator.startAnimation()
            runningAnimations.append(cornerRadiusAnimator)
            
            let blurAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.visualEffectView.effect = UIBlurEffect(style: .dark)
                    
                case .collapsed:
                    self.visualEffectView.effect = nil
                }
            }
            blurAnimator.startAnimation()
            runningAnimations.append(blurAnimator)
            
            let rotateAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.peripheralViewController.handleImage.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                case .collapsed:
                    self.peripheralViewController.handleImage.transform = CGAffineTransform(rotationAngle: 0)
                }
            }
            rotateAnimator.startAnimation()
            runningAnimations.append(rotateAnimator)
        }
    }
    
    func startTransition(state: PeripheralVCState, duration: TimeInterval) {
        if runningAnimations.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
        }
        for animator in runningAnimations {
            animator.pauseAnimation()
            animationProgressWhenInterrupted = animator.fractionComplete
        }
    }
    
    func updateTransition(fractionCompleted: CGFloat) {
        for animator in runningAnimations {
            animator.fractionComplete = fractionCompleted + animationProgressWhenInterrupted
        }
    }
    
    func continueTransition() {
        for animator in runningAnimations {
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        }
    }
    
    func sendData(value: Int8) -> Bool {
        guard let peripheral = robotPeripheral, let characteristic = TxCharacteristic else { return false }
        peripheral.writeValue(Data.dataWithValue(value: value), for: characteristic, type: .withResponse)
        return true
    }
    
    func scan() {
        print("scanning")
        centralManager.scanForPeripherals(withServices: [kUartServiceUUID, kUartTxCharacteristicUUID, kUartRxCharacteristicUUID], options: nil)
    }
    
    @IBAction func disconnectButtonDidPress(_ sender: Any) {
        guard let peripheral = robotPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        statusLabel.text = "DISCONNECTED"
    }
    
    @IBAction func forwardDidPress(_ sender: Any) {
        let val = Int8(Array("w".utf8)[0])
        if sendData(value: val) {
            statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
        }
    }
    
    @IBAction func rightDidPress(_ sender: Any) {
        let val = Int8(Array("d".utf8)[0])
        if sendData(value: val) {
            statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
        }
    }
    
    @IBAction func backwardDidPress(_ sender: Any) {
        let val = Int8(Array("s".utf8)[0])
        if sendData(value: val) {
            statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
        }
    }
    
    @IBAction func leftDidPress(_ sender: Any) {
        let val = Int8(Array("a".utf8)[0])
        if sendData(value: val) {
            statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
        }
    }
    
    @IBAction func stopDidPress(_ sender: Any) {
        let val = Int8(Array("q".utf8)[0])
        if sendData(value: val) {
            statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
        }
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            scan()
        }
        else {
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Be sure that you have bluetooth turned on!", preferredStyle: UIAlertController.Style.alert)
            let action = UIAlertAction(title: "ok", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name != nil && peripheral.name!.contains("ROBOTIS_410") {
            peripherals.append(peripheral)
            peripheral.delegate = self
            
            if let loading = loadingIndicator {
                if loading.isAnimating {
                    loading.stopAnimating()
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        robotPeripheral.discoverServices(nil)
        statusLabel.text = "CONNECTED"
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == kUartServiceUUID {
                targetService = service
                robotPeripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == kUartTxCharacteristicUUID {
                TxCharacteristic = characteristic
            }
            else if characteristic.uuid == kUartRxCharacteristicUUID {
                RxCharacteristic = characteristic
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        switch characteristic.uuid {
        case kUartRxCharacteristicUUID:
            let char = getData(from: characteristic)
            statusLabel.text = "Recieved a: \(char)"
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    private func getData(from characteristic: CBCharacteristic) -> Character {
        guard let characteristicData = characteristic.value, let byte = characteristicData.first else {return Character("E")}
        return Character(UnicodeScalar(byte))
    }
}

extension Data {
    static func dataWithValue(value: Int8) -> Data {
        var variableValue = value
        return Data(buffer: UnsafeBufferPointer(start: &variableValue, count: 1))
    }
    
    func int8Value() -> Int8 {
        return Int8(bitPattern: self[0])
    }
}
