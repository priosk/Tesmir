import Foundation
import Network
import Combine
import Darwin.POSIX.ifaddrs
import Darwin.POSIX.netinet.`in`
import Darwin.POSIX.arpa.inet
import Darwin.POSIX.net.`if`

class NetworkMonitor: ObservableObject {
    @Published var localIPAddress: String? = nil
    @Published var networkQuality: NetworkQuality = .unknown
    @Published var isConnected: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tesmir.networkmonitor")
    private var refreshTimer: Timer?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.handlePathUpdate(path) }
        }
        monitor.start(queue: queue)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshLocalIP()
        }
        refreshTimer?.fire()
    }

    func stop() {
        monitor.cancel()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func handlePathUpdate(_ path: NWPath) {
        isConnected = path.status == .satisfied
        if path.status == .satisfied {
            refreshLocalIP()
            networkQuality = path.usesInterfaceType(.cellular) ? .fair : .good
        } else {
            localIPAddress = nil
            networkQuality = .poor
        }
    }

    func refreshLocalIP() {
        let ip = Self.getLocalIPAddress()
        DispatchQueue.main.async { [weak self] in
            self?.localIPAddress = ip
            if ip != nil { self?.networkQuality = .good }
        }
    }

    static func getLocalIPAddress() -> String? {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0 else { return nil }
        defer { freeifaddrs(addressList) }
        var preferredIP: String? = nil
        var fallbackIP: String? = nil
        var ptr = addressList
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp && isRunning && !isLoopback {
                let family = current.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    var addr = current.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                    let ipString = String(cString: buffer)
                    let ifName = String(cString: current.pointee.ifa_name)
                    if ifName == "en0" { preferredIP = ipString }
                    else { fallbackIP = fallbackIP ?? ipString }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return preferredIP ?? fallbackIP
    }
}
