import UIKit
import CoreBluetooth
import UserNotifications

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var labelMessage: UILabel!
    @IBOutlet weak var buttonConnect: UIButton!
    @IBOutlet weak var buttonDisconnect: UIButton!

    var labelSize : CGRect!
    var centralManager: CBCentralManager!
    
    var peripheral : CBPeripheral!
    
    var messages : Array<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        labelMessage.numberOfLines = 0
        labelMessage.lineBreakMode = NSLineBreakMode.byCharWrapping
        labelSize = labelMessage.frame;
        
        message("viewDidLoad");
        
        updateUI(false)
        
        let options: Dictionary = [
            CBCentralManagerOptionRestoreIdentifierKey: "SensorTagTest"
        ]
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: options)
    }

    override func didReceiveMemoryWarning() {
        message("didReceiveMemoryWarning");
        super.didReceiveMemoryWarning()
    }

    @IBAction func onButtonConnectTouchDown(_ sender: Any) {
        message("onButtonConnectTouchDown");
        bleStart();
    }
    
    @IBAction func onButtonDisconnectTouchDown(_ sender: Any) {
        message("onButtonDisconnectTouchDown");
        bleStop();
    }
    
    func updateUI(_ flag:Bool) {
        buttonConnect.isEnabled = !flag
        buttonDisconnect.isEnabled = flag
    }

    /////////////////////////////////////////////////////////////////////////////////////

    func bleStart() {
        message("bleStart");

        updateUI(true)

        centralManager.scanForPeripherals(
            withServices: nil,
            options: nil
        )
    }
    
    func bleConnect(_ central:CBCentralManager, _ peripheral:CBPeripheral) {
        message("bleConnect");
        self.peripheral = peripheral
        central.stopScan()
        central.connect(peripheral, options: nil)
    }
    
    func bleStop() {
        message("bleStop");
        
        updateUI(false)
        
        if peripheral != nil {
            centralManager.cancelPeripheralConnection(peripheral)
            peripheral = nil
        }

        centralManager.stopScan()
    }
    
    /////////////////////////////////////////////////////////////////////////////////////

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        message("centralManagerDidUpdateState");

        switch (central.state) {
        case .poweredOff:
            message("centralManagerDidUpdateState : central.state = .poweredOff")
        case .poweredOn:
            message("centralManagerDidUpdateState : central.state = .poweredOn")
        case .resetting:
            message("centralManagerDidUpdateState : central.state = .resetting")
        case .unauthorized:
            message("centralManagerDidUpdateState : central.state = .unauthorized")
        case .unknown:
            message("centralManagerDidUpdateState : central.state = .unknown")
        case .unsupported:
            message("centralManagerDidUpdateState : central.state = .unsupported")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        message("centralManager:didDiscover: peripheral:\(peripheral), RSSI:\(RSSI)")

//        var str = "";
//        advertisementData.forEach { key, value in
//            str += "\(key)=\(value),"
//        }
//        message(str);
        
        let kCBAdvDataLocalName = advertisementData["kCBAdvDataLocalName"] as? String
        if kCBAdvDataLocalName == "SensorTag" {
            bleConnect(central, peripheral);
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        message("centralManager:willRestoreState : central.state=\(central.state.rawValue)")

        // restore member variables...
        self.centralManager = central

        if let peripherals:[CBPeripheral] = dict[CBCentralManagerRestoredStatePeripheralsKey] as! [CBPeripheral]? {
            peripherals.forEach { p in
                if p.state == CBPeripheralState.connected {
                    self.peripheral = p
                    self.peripheral.delegate = self // <= !!!! IMPORTANT !!!!
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        message("centralManager:didConnect");

        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        message("centralManager:didFailToConnect");
        bleStop();
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        message("centralManager:didDisconnectPeripheral");
        bleStop();
    }

    /////////////////////////////////////////////////////////////////////////////////////

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        message("peripheral:didDiscoverServices");
        
        guard let services = peripheral.services, !services.isEmpty else { return }
        for service in services {
            // key service
            if service.uuid == CBUUID(string:"0000ffe0-0000-1000-8000-00805f9b34fb") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        message("peripheral:didDiscoverCharacteristicsFor");

        guard let characteristics = service.characteristics, !characteristics.isEmpty else { return }
        for characteristic in characteristics {
            // key press/release notification
            if characteristic.uuid == CBUUID(string:"0000ffe1-0000-1000-8000-00805f9b34fb") {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        message("peripheral:didWriteValueFor");
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == CBUUID(string:"0000ffe1-0000-1000-8000-00805f9b34fb") {
            let hex = characteristic.value?.map {
                String(format: "%.2hhx", $0)
            }.joined()
            message("peripheral:didUpdateValueFor : peripheral.vaue!=" + hex!)
            
            if hex! == "01" {
                notificationTest()
            }
        }
        else {
            message("peripheral:didUpdateValueFor : invalid uuid....\(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {

        if error != nil {
            message("peripheral:didUpdateNotificationStateFor : error = \(error!)");
        }
        else {
            message("peripheral:didUpdateNotificationStateFor : characteristic.isNotifying = \(characteristic.isNotifying)");
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        message("peripheral:didUpdateValueFor...");
    }

    /////////////////////////////////////////////////////////////////////////////////////
    
    func notificationTest() {
        message("notificationTest");
        
        let content = UNMutableNotificationContent()
        content.title = "SensorTag"
        content.body = "Press Button 01"
        content.sound = UNNotificationSound.default()
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(1),
            repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "SensorTagTest",
            content: content,
            trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { (error) in
            if let error = error {
                self.message(error.localizedDescription)
            }
        }
    }
    
    func message(_ msg:String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss : "
            let now = Date()
            let date_str = formatter.string(from: now)
            
            print(date_str + msg)
            
            self.messages.append(date_str + msg)
            if self.messages.count > 10 {
                self.messages.removeFirst()
            }
            
            var str = ""
            self.messages.forEach { s in
                str += s
                str += "\n"
            }
            
            self.labelMessage.text = str
            self.labelMessage.frame = self.labelSize;
            self.labelMessage.sizeToFit()
        }
    }
}

