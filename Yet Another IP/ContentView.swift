import SwiftUI
import Combine
import Network
import Darwin

struct ContentView: View {
    @StateObject private var networkInfo = NetworkInfo()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.12),
                    Color.blue.opacity(0.06),
                    Color.primary.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: 150, y: -260)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        Text("NETWORK DETAILS")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        informationCard(
                            title: "Hostname",
                            detail: "Device name",
                            value: networkInfo.hostname,
                            symbol: "desktopcomputer",
                            tint: .indigo
                        )
                        informationCard(
                            title: "Ethernet",
                            detail: "Wired connection",
                            value: networkInfo.ethernetAddress,
                            symbol: "cable.connector",
                            tint: .blue
                        )
                        informationCard(
                            title: "Wi-Fi",
                            detail: "Wireless connection",
                            value: networkInfo.wifiAddress,
                            symbol: "wifi",
                            tint: .cyan
                        )
                    }

                    Text("Your network information is updated automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 22)
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "network")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .blue.opacity(0.25), radius: 12, y: 6)

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(networkInfo.isConnected ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(networkInfo.isConnected ? "Connected" : "Offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Yet Another IP")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("A clear view of your device and network.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func informationCard(
        title: String,
        detail: String,
        value: String,
        symbol: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if value != "Not Connected" {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("Connected")
                    }
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(value == "Not Connected" ? .secondary : .primary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
    }
}

@MainActor
private final class NetworkInfo: ObservableObject {
    @Published private(set) var hostname = "Not Connected"
    @Published private(set) var ethernetAddress = "Not Connected"
    @Published private(set) var wifiAddress = "Not Connected"

    var isConnected: Bool {
        ethernetAddress != "Not Connected" || wifiAddress != "Not Connected"
    }

    private let ethernetMonitor = NWPathMonitor(requiredInterfaceType: .wiredEthernet)
    private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)

    init() {
        hostname = Self.deviceHostname()
        observe(ethernetMonitor, interfaceType: .wiredEthernet) { [weak self] address in
            self?.ethernetAddress = address
        }
        observe(wifiMonitor, interfaceType: .wifi) { [weak self] address in
            self?.wifiAddress = address
        }
    }

    private func observe(
        _ monitor: NWPathMonitor,
        interfaceType: NWInterface.InterfaceType,
        update: @escaping (String) -> Void
    ) {
        monitor.pathUpdateHandler = { path in
            let interfaceName = path.status == .satisfied
                ? path.availableInterfaces.first(where: { $0.type == interfaceType })?.name
                : nil

            Task { @MainActor in
                let address = interfaceName.flatMap(Self.ipv4Address(for:)) ?? "Not Connected"
                update(address)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    private static func deviceHostname() -> String {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard gethostname(&buffer, buffer.count) == 0 else {
            return "Not Connected"
        }
        let hostname = String(cString: buffer)
        return hostname.isEmpty ? "Not Connected" : hostname
    }

    private static func ipv4Address(for interfaceName: String) -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var currentInterface: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let interfacePointer = currentInterface {
            let interface = interfacePointer.pointee
            if let name = interface.ifa_name,
               String(cString: name) == interfaceName,
               let address = interface.ifa_addr,
               address.pointee.sa_family == UInt8(AF_INET),
               interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0 {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    address,
                    socklen_t(address.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    return String(cString: host)
                }
            }
            currentInterface = interface.ifa_next
        }
        return nil
    }
}

#Preview {
    ContentView()
}
