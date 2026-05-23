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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
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
        let ip = Self.getHotspotIPAddress()
        DispatchQueue.main.async { [weak self] in
            self?.localIPAddress = ip
            if ip != nil { self?.networkQuality = .good }
        }
    }

    /// iPhone 핫스팟 IP를 반환합니다.
    /// bridge100 (핫스팟) → en0 (WiFi) 순으로 우선순위
    static func getHotspotIPAddress() -> String? {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0 else { return nil }
        defer { freeifaddrs(addressList) }

        // 우선순위: bridge100 (핫스팟) > en0 (WiFi) > 기타
        let preferredInterfaces = ["bridge100", "en0"]
        var results: [String: String] = [:]

        var ptr = addressList
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && isRunning && !isLoopback,
               current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                var addr = current.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                let ipString = String(cString: buffer)
                let ifName = String(cString: current.pointee.ifa_name)

                // 192.0.0.x (USB 테더링 주소) 제외
                if !ipString.hasPrefix("192.0.0") {
                    results[ifName] = ipString
                }
            }
            ptr = current.pointee.ifa_next
        }

        // 우선순위대로 반환
        for iface in preferredInterfaces {
            if let ip = results[iface] { return ip }
        }
        // 그 외 첫 번째 IP 반환
        return results.values.first
    }
}
