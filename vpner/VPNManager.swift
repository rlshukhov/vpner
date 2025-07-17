//
//  VPNManager.swift
//  vpner
//
//  Created by Lane Shukhov on 11.07.2025.
//

import Foundation

protocol VPNManagerDelegate: AnyObject {
    func vpnStatusDidChange(isConnected: Bool)
}

class VPNManager: ObservableObject {
    @Published var networkServices: [String] = []
    @Published var selectedService: String? {
        didSet {
            UserDefaults.standard.set(selectedService, forKey: "selectedVPNService")
            if selectedService != nil {
                startMonitoring()
            }
        }
    }
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    
    weak var delegate: VPNManagerDelegate?
    private var statusTimer: Timer?
    
    init() {
        loadSelectedService()
        loadNetworkServices()
    }
    
    private func loadSelectedService() {
        selectedService = UserDefaults.standard.string(forKey: "selectedVPNService")
    }
    
    func loadNetworkServices() {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallnetworkservices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        let lines = output.components(separatedBy: .newlines)
        var services: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty &&
               !trimmed.contains("asterisk") &&
               !trimmed.contains("Thunderbolt") &&
               !trimmed.contains("Wi-Fi") {
                let cleaned = trimmed.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    services.append(cleaned)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.networkServices = services
        }
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        guard selectedService != nil else { return }
        
        checkConnectionStatus()
        
        statusTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.checkConnectionStatus()
        }
    }
    
    func stopMonitoring() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    private func checkConnectionStatus() {
        guard let service = selectedService else { return }
        
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-showpppoestatus", service]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        let connected = output.trimmingCharacters(in: .whitespacesAndNewlines) == "connected"
        
        DispatchQueue.main.async {
            if self.isConnected != connected {
                self.isConnected = connected
                self.delegate?.vpnStatusDidChange(isConnected: connected)
            }
        }
    }
    
    func connect() {
        guard let service = selectedService else { return }
        
        isConnecting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/sbin/networksetup"
            task.arguments = ["-connectpppoeservice", service]
            task.launch()
            task.waitUntilExit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isConnecting = false
                self.checkConnectionStatus()
            }
        }
    }
    
    func disconnect() {
        guard let service = selectedService else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/sbin/networksetup"
            task.arguments = ["-disconnectpppoeservice", service]
            task.launch()
            task.waitUntilExit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkConnectionStatus()
            }
        }
    }
}
