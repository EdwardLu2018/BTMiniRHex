//
//  ViewController.swift
//  BTTest-MiniRhex
//
//  Created by Edward on 6/26/19.
//  Copyright © 2019 Edward. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var centralManager: CBCentralManager!
    var robotPeripheral: CBPeripheral!
    var connected: Bool = false
    var peripherals = [CBPeripheral]()
    var peripheralIndex: Int = 0
    
    @IBOutlet weak var forward: UIButton!
    @IBOutlet weak var right: UIButton!
    @IBOutlet weak var backward: UIButton!
    @IBOutlet weak var left: UIButton!
    @IBOutlet weak var stop: UIButton!
    @IBOutlet weak var connect: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    static let kUartServiceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    static let kUartTxCharacteristicUUID = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    static let kUartRxCharacteristicUUID = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
    var targetService: CBService?
    var TxCharacteristic: CBCharacteristic?
    var RxCharacteristic: CBCharacteristic?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        statusLabel.text = "Scanning for MiniRHexs..."
        
        forward.isHidden = true
        right.isHidden = true
        backward.isHidden = true
        left.isHidden = true
        stop.isHidden = true
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.tableView.center.y += self.tableView.bounds.height
        UIView.animate(withDuration: 1) {
            self.tableView.center.y -= self.tableView.bounds.height
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        robotPeripheral = peripherals[indexPath.row]
        tableView.isHidden = true
        UIView.animate(withDuration: 0.75) {
            self.tableView.alpha = 0.0
        }
        centralManager.connect(robotPeripheral)
        forward.isHidden = false
        right.isHidden = false
        backward.isHidden = false
        left.isHidden = false
        stop.isHidden = false
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "miniRHexCell", for: indexPath) as? TableViewCell else {
            fatalError("The dequeued cell is not an instance of SongTableViewCell.")
        }
        cell.title.text = peripherals[indexPath.row].identifier.uuidString
        return cell
    }
    
    func sendData(value: Int8) {
        guard let peripheral = robotPeripheral, let characteristic = TxCharacteristic else { return }
        peripheral.writeValue(Data.dataWithValue(value: value), for: characteristic, type: .withResponse)
    }
    
    func scan() {
        centralManager.scanForPeripherals(withServices: [ViewController.kUartServiceUUID, ViewController.kUartTxCharacteristicUUID, ViewController.kUartRxCharacteristicUUID], options: nil)
    }
    
    @IBAction func connectionButtonDidPress(_ sender: Any) {
        if robotPeripheral != nil {
            centralManager.cancelPeripheralConnection(robotPeripheral)
            statusLabel.text = "DISCONNECTED"
            tableView.isHidden = false
            UIView.animate(withDuration: 0.75) {
                self.tableView.alpha = 1.0
            }
            forward.isHidden = true
            right.isHidden = true
            backward.isHidden = true
            left.isHidden = true
            stop.isHidden = true
        }
    }
    
    @IBAction func forwardDidPress(_ sender: Any) {
        let val = Int8(Array("w".utf8)[0])
        sendData(value: val)
        statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
    }
    
    @IBAction func rightDidPress(_ sender: Any) {
        let val = Int8(Array("d".utf8)[0])
        sendData(value: val)
        statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
    }
    
    @IBAction func backwardDidPress(_ sender: Any) {
        let val = Int8(Array("s".utf8)[0])
        sendData(value: val)
        statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
    }
    
    @IBAction func leftDidPress(_ sender: Any) {
        let val = Int8(Array("a".utf8)[0])
        sendData(value: val)
        statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
    }
    
    @IBAction func stopDidPress(_ sender: Any) {
        let val = Int8(Array("q".utf8)[0])
        sendData(value: val)
        statusLabel.text = "Sent a: \(Character(UnicodeScalar(Int(val))!))"
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            scan()
        }
        else {
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on", preferredStyle: UIAlertController.Style.alert)
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
        }
        tableView.reloadData()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        robotPeripheral.discoverServices(nil)
        connected = true
        statusLabel.text = "CONNECTED"
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == ViewController.kUartServiceUUID {
                targetService = service
                robotPeripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == ViewController.kUartTxCharacteristicUUID {
                TxCharacteristic = characteristic
            }
            else if characteristic.uuid == ViewController.kUartRxCharacteristicUUID {
                RxCharacteristic = characteristic
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        switch characteristic.uuid {
        case ViewController.kUartRxCharacteristicUUID:
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
