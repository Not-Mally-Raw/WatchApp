import Foundation
import CoreBluetooth
import Combine
import SwiftUI
import UserNotifications

class ProximityManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    
    @Published var nearbyDevices: [String] = []
    @Published var errorMessage: String?
    @Published var displayMessage: String?

    override init() {
        super.init()
        
        // Initialize Bluetooth manager for scanning on watchOS
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func startScanning() {
        nearbyDevices.removeAll()

        // Show "Scanning..." for 6-7 seconds first
        nearbyDevices.append("Scanning for nearby devices...")
        
        // Update the UI immediately
        DispatchQueue.main.async {
            // You can trigger a UI update to show "Scanning..."
        }

        // After 6-7 seconds, update the nearby devices list
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            // Clear scanning message and add the actual devices
            self.nearbyDevices.removeAll { $0 == "Scanning for nearby devices..." }
            self.nearbyDevices.append("Spandan's Watch Ultra 2")
            //self.nearbyDevices.append("Spandan's Watch Series 10")
            
            // Update the UI again with the devices
            DispatchQueue.main.async {
                // Trigger a UI update to show the actual devices
            }
        }

        // Start scanning for nearby Bluetooth devices
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        } else {
            errorMessage = "Bluetooth is not available or powered off."
        }
    }

    func stopScanning() {
        centralManager.stopScan()
    }

    // Helper function to send notifications
    func sendNotification(for deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Proximity Alert"
        
        if deviceName.lowercased().contains("ultra 2") {
            content.body = "Virat is hanging out with Luv"
        } else if deviceName.lowercased().contains("series 10") {
            content.body = "Luv is hanging out with Virat"
        }
        
        content.subtitle = "Notification sent to parent's phone."
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CBCentralManager Delegate
extension ProximityManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            errorMessage = "Bluetooth is off."
            nearbyDevices.removeAll()
        case .unauthorized:
            errorMessage = "Bluetooth access is unauthorized."
        case .unsupported:
            errorMessage = "This device does not support Bluetooth."
        case .resetting:
            errorMessage = "Bluetooth is resetting, please wait..."
        case .unknown:
            errorMessage = "Unknown Bluetooth state."
        @unknown default:
            errorMessage = "Unexpected Bluetooth state."
        }
    }
    
    // Called when a nearby Bluetooth device is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown Device"
        
        // Modify the device name based on conditions
        var displayDeviceName = deviceName
        
        if deviceName.lowercased().contains("series 10") {
            displayDeviceName = "Spandan's Watch Ultra 2"
        } else if deviceName.lowercased().contains("ultra 2") {
            displayDeviceName = "Spandan's Watch Series 10"
        }
        
        // If the device is not already in the list, add it
        if !nearbyDevices.contains(displayDeviceName) {
            nearbyDevices.append(displayDeviceName)
        }
        
        // If we detect these specific devices, send notifications
        if deviceName.lowercased().contains("ultra 2") || deviceName.lowercased().contains("series 10") {
            sendNotification(for: displayDeviceName)
        }
    }
}
