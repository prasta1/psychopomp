import Foundation
@preconcurrency import Dispatch
@preconcurrency import Network

/// Discovers AI model servers on the local network via mDNS (Bonjour) and
/// direct port probing. Returns endpoints that respond to `/v1/models`.
@MainActor
final class NetworkDiscovery: ObservableObject {
    @Published var discovered: [DiscoveredEndpoint] = []
    @Published var isScanning = false

    private var browser: NWBrowser?

    struct DiscoveredEndpoint: Identifiable, Hashable, Sendable {
        let id = UUID()
        let host: String
        let port: UInt16
        let name: String
        let source: Source

        enum Source: String, Sendable {
            case mdns, probe
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(host)
            hasher.combine(port)
        }

        static func == (lhs: DiscoveredEndpoint, rhs: DiscoveredEndpoint) -> Bool {
            lhs.host == rhs.host && lhs.port == rhs.port
        }
    }

    /// Known default ports for popular AI servers.
    private static let knownPorts: [(UInt16, String)] = [
        (1234, "LM Studio"),
        (11434, "Ollama"),
        (8642, "Hermes"),
    ]

    // MARK: - Public

    func startDiscovery() {
        guard !isScanning else { return }
        isScanning = true
        discovered = []

        startMBrowser()
        probeKnownPorts()
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }

    // MARK: - mDNS

    private func startMBrowser() {
        let params = NWParameters()
        params.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: params)
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed = state {
                Task { @MainActor in self.isScanning = false }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for result in results {
                    await self.handleMBrowserResult(result)
                }
            }
        }

        browser.start(queue: .global(qos: .userInitiated))
    }

    private func handleMBrowserResult(_ result: NWBrowser.Result) async {
        guard case .service(let name, _, _, _) = result.endpoint else { return }

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let path = connection.currentPath,
                       let remote = path.remoteEndpoint,
                       case .hostPort(let endpointHost, let endpointPort) = remote {
                        var hostStr = ""
                        switch endpointHost {
                        case .ipv4(let addr): hostStr = "\(addr)"
                        case .ipv6(let addr): hostStr = "\(addr)"
                        case .name: break
                        @unknown default: break
                        }
                        if !hostStr.isEmpty {
                            let capturedName = name
                            let capturedPort = endpointPort.rawValue
                            Task { @MainActor in
                                self.addDiscovered(host: hostStr, port: capturedPort, name: capturedName, source: .mdns)
                            }
                        }
                    }
                    connection.cancel()
                    continuation.resume()
                case .setup, .preparing:
                    break
                case .waiting, .failed, .cancelled:
                    continuation.resume()
                @unknown default:
                    continuation.resume()
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                connection.cancel()
            }
        }
    }

    // MARK: - Port probing

    private func probeKnownPorts() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            guard let iface = path.availableInterfaces.first else { return }
            let localIP = Self.localIPAddress(for: iface)
            monitor.cancel()
            guard let baseIP = localIP else { return }
            Task { @MainActor in
                self.probeSubnet(baseIP: baseIP)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .userInitiated))
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            monitor.cancel()
        }
    }

    private nonisolated static func localIPAddress(for iface: NWInterface) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = start
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let name = String(cString: current.pointee.ifa_name)
            guard name == iface.name else { continue }
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            return String(cString: hostname)
        }
        return nil
    }

    private func probeSubnet(baseIP: String) {
        guard let lastDot = baseIP.lastIndex(of: ".") else { return }
        let prefix = String(baseIP[..<lastDot])

        let queue = DispatchQueue(label: "probe", qos: .userInitiated, attributes: .concurrent)

        for i in 1...254 {
            let ip = "\(prefix).\(i)"
            for (port, name) in Self.knownPorts {
                queue.async {
                    self.probeEndpoint(host: ip, port: port, name: name)
                }
            }
        }
    }

    private nonisolated func probeEndpoint(host: String, port: UInt16, name: String) {
        let conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        let hostCaptured = host
        let portCaptured = port
        let nameCaptured = name

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { conn.cancel() }
                self.httpProbe(host: hostCaptured, port: portCaptured, name: nameCaptured) { conn.cancel() }
            case .setup, .preparing, .waiting, .failed, .cancelled:
                break
            @unknown default:
                break
            }
        }

        conn.start(queue: .global(qos: .userInitiated))
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            conn.cancel()
        }
    }

    private nonisolated func httpProbe(host: String, port: UInt16, name: String, completion: @escaping @Sendable () -> Void) {
        guard let url = URL(string: "http://\(host):\(port)/v1/models") else { completion(); return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        req.httpMethod = "GET"

        URLSession.shared.dataTask(with: req) { data, response, _ in
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let _ = json["data"] else {
                completion()
                return
            }
            let ep = DiscoveredEndpoint(host: host, port: port, name: name, source: .probe)
            Task { @MainActor in
                if !self.discovered.contains(ep) {
                    self.discovered.append(ep)
                }
            }
            completion()
        }.resume()
    }

    // MARK: - Helpers

    private func addDiscovered(host: String, port: UInt16, name: String, source: DiscoveredEndpoint.Source) {
        let ep = DiscoveredEndpoint(host: host, port: port, name: name, source: source)
        guard !discovered.contains(ep) else { return }
        discovered.append(ep)
    }
}
