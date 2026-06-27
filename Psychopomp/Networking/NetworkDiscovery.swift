import Foundation
import Network

/// Discovers AI model servers on the local network via mDNS (Bonjour) and
/// direct port probing. Returns endpoints that respond to `/v1/models`.
@MainActor
final class NetworkDiscovery: ObservableObject {
    @Published var discovered: [DiscoveredEndpoint] = []
    @Published var isScanning = false

    private var browser: NWBrowser?

    struct DiscoveredEndpoint: Identifiable, Hashable {
        let id = UUID()
        let host: String
        let port: UInt16
        let name: String
        let source: Source

        enum Source: String {
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
        guard let endpoint = result.endpoint as? NWEndpoint,
              case .service(let name, _, _, _) = endpoint else { return }

        let connection = NWConnection(to: endpoint, using: .tcp)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    if let path = connection.currentPath,
                       let remote = path.remoteEndpoint,
                       case .hostPort(let host, let port) = remote {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr): hostStr = "\(addr)"
                        case .ipv6(let addr): hostStr = "\(addr)"
                        @unknown default:
                            connection.cancel()
                            continuation.resume()
                            return
                        }
                        Task { @MainActor in
                            self.addDiscovered(host: hostStr, port: port.rawValue, name: name, source: .mdns)
                        }
                    }
                    connection.cancel()
                    continuation.resume()
                } else {
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
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = first
        while ptr != nil {
            defer { ptr = ptr.pointee.ifa_next }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name == iface.name else { continue }
            let addr = ptr.pointee.ifa_addr
            guard addr != nil else { continue }
            if addr!.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr!.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                return String(cString: hostname)
            }
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
        let timeout = DispatchWorkItem { conn.cancel() }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { timeout.cancel() }
                self.httpProbe(host: host, port: port, name: name) { conn.cancel() }
            case .failed, .cancelled:
                timeout.cancel()
            default:
                break
            }
        }

        conn.start(queue: .global(qos: .userInitiated))
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5, execute: timeout)
    }

    private nonisolated func httpProbe(host: String, port: UInt16, name: String, completion: @escaping () -> Void) {
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
            Task { @MainActor in
                self.addDiscovered(host: host, port: port, name: name, source: .probe)
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
