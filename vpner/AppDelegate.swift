//
//  AppDelegate.swift
//  vpner
//
//  Created by Lane Shukhov on 14.07.2025.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var statusMenu: NSMenu!
    var vpnManager = VPNManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "shield", accessibilityDescription: "VPN Status")
        }
        
        vpnManager.delegate = self
        vpnManager.loadNetworkServices()
        vpnManager.startMonitoring()
        
        setupMenu()
    }
    
    func setupMenu() {
        statusMenu = NSMenu()
        
        let selectedItem = NSMenuItem(title: "Selected: None", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        selectedItem.submenu = submenu
        statusMenu.addItem(selectedItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        let connectItem = NSMenuItem(title: "Connect", action: #selector(toggleConnection), keyEquivalent: "")
        connectItem.target = self
        connectItem.tag = 1
        statusMenu.addItem(connectItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        statusMenu.addItem(quitItem)
        
        updateMenu()
    }
    
    func updateMenu() {
        guard let menu = statusMenu else { return }
        
        let selectedItem = menu.item(at: 0)!
        selectedItem.title = "Selected: \(vpnManager.selectedService ?? "None")"
        
        let submenu = NSMenu()
        
        let noneItem = NSMenuItem(title: "None", action: #selector(selectService(_:)), keyEquivalent: "")
        noneItem.target = self
        noneItem.representedObject = nil
        if vpnManager.selectedService == nil {
            noneItem.state = .on
        }
        submenu.addItem(noneItem)
        
        for service in vpnManager.networkServices {
            let item = NSMenuItem(title: service, action: #selector(selectService(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = service
            if service == vpnManager.selectedService {
                item.state = .on
            }
            submenu.addItem(item)
        }
        
        selectedItem.submenu = submenu
        
        if let connectItem = menu.item(withTag: 1) {
            connectItem.title = vpnManager.isConnected ? "Disconnect" : "Connect"
            connectItem.isEnabled = vpnManager.selectedService != nil
        }
        
        statusBarItem.menu = statusMenu
    }
    
    @objc func selectService(_ sender: NSMenuItem) {
        vpnManager.selectedService = sender.representedObject as? String
        updateMenu()
    }
    
    @objc func toggleConnection() {
        if vpnManager.isConnected {
            vpnManager.disconnect()
        } else {
            vpnManager.connect()
        }
    }
    
    @objc func quit() {
        NSApp.terminate(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        vpnManager.stopMonitoring()
    }
}

// MARK: - VPNManagerDelegate
extension AppDelegate: VPNManagerDelegate {
    func vpnStatusDidChange(isConnected: Bool) {
        DispatchQueue.main.async {
            self.updateStatusBarIcon(isConnected: isConnected)
            self.updateMenu()
        }
    }
    
    func updateStatusBarIcon(isConnected: Bool) {
        if let button = statusBarItem.button {
            let imageName = isConnected ? "shield.fill" : "shield"
            let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "VPN Status")
            image!.isTemplate = !isConnected
            button.image = isConnected ? self.tintImage(image!, color: .systemGreen) : image
        }
    }
    
    private func tintImage(_ image: NSImage, color: NSColor) -> NSImage {
        let tinted = image.copy() as! NSImage
        tinted.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }
}
