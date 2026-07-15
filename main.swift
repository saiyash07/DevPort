import AppKit
import Foundation

struct LocalPort {
    let port: Int
    let processName: String
    let pid: Int
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var activePorts: [LocalPort] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set application to run as a background accessory app (no dock icon, no main windows)
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Menu Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🔌 ?"
        }
        
        // Setup Dynamic Menu
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        
        // Initial scan and start timer (every 3 seconds)
        refreshPorts()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshPorts()
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        if activePorts.isEmpty {
            let noPortsItem = NSMenuItem(title: "No Active Ports", action: nil, keyEquivalent: "")
            noPortsItem.isEnabled = false
            menu.addItem(noPortsItem)
        } else {
            let headerItem = NSMenuItem(title: "Active Ports:", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            
            for item in activePorts {
                let portMenuItem = NSMenuItem(title: "Port \(item.port) ( \(item.processName) )", action: nil, keyEquivalent: "")
                
                let submenu = NSMenu()
                
                let openItem = NSMenuItem(title: "Open http://localhost:\(item.port)", action: #selector(openPort(_:)), keyEquivalent: "")
                openItem.target = self
                openItem.representedObject = item.port
                submenu.addItem(openItem)
                
                let killItem = NSMenuItem(title: "Kill Process (PID \(item.pid))", action: #selector(killProcess(_:)), keyEquivalent: "")
                killItem.target = self
                killItem.representedObject = item.pid
                submenu.addItem(killItem)
                
                portMenuItem.submenu = submenu
                menu.addItem(portMenuItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(forceRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        let quitItem = NSMenuItem(title: "Quit DevPort", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func forceRefresh() {
        refreshPorts()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func openPort(_ sender: NSMenuItem) {
        if let port = sender.representedObject as? Int {
            if let url = URL(string: "http://localhost:\(port)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func killProcess(_ sender: NSMenuItem) {
        if let pid = sender.representedObject as? Int {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/kill")
            process.arguments = ["-9", "\(pid)"]
            do {
                try process.run()
                process.waitUntilExit()
                refreshPorts()
            } catch {
                print("Failed to kill process with PID \(pid): \(error)")
            }
        }
    }
    
    func refreshPorts() {
        let ports = scanPorts()
        self.activePorts = ports
        
        if let button = statusItem?.button {
            if ports.isEmpty {
                button.title = "🔌 0"
            } else {
                button.title = "🔌 \(ports.count)"
            }
        }
    }
    
    func scanPorts() -> [LocalPort] {
        var ports: [LocalPort] = []
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Silence stderr
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                var seenPorts = Set<Int>()
                
                for line in lines {
                    let parts = line.split(separator: " ").map { String($0) }
                    if parts.count >= 9 {
                        let procName = parts[0]
                        if let pid = Int(parts[1]) {
                            let nameCol = parts[8]
                            if let portStr = nameCol.components(separatedBy: ":").last,
                               let port = Int(portStr) {
                                if !seenPorts.contains(port) {
                                    seenPorts.insert(port)
                                    ports.append(LocalPort(port: port, processName: procName, pid: pid))
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error scanning ports: \(error)")
        }
        
        return ports.sorted { $0.port < $1.port }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
