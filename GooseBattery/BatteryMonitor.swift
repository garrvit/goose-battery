import Foundation
import IOKit
import IOKit.ps
import Combine

struct BatterySnapshot: Equatable {
    let timestamp: Date
    let percentage: Int
    let stateDescription: String
    let externalConnected: Bool
    let isCharging: Bool
    let currentCapacityMah: Int
    let maxCapacityMah: Int
    let designCapacityMah: Int
    let emptyCapacityMah: Int
    let cycleCount: Int
    let healthPercent: Double
    let adapterWatts: Double?
    let batteryPowerWatts: Double?
    let netFlowMilliAmps: Int
    let chargingSpeedMahPerHour: Int
    let consumptionMahPerHour: Int
    let temperatureCelsius: Double?

    var capacityFraction: Double {
        guard maxCapacityMah > 0 else { return 0 }
        return Double(currentCapacityMah) / Double(maxCapacityMah)
    }
}

struct BatteryHistoryPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let netFlowMilliAmps: Int
}

enum BatteryReaderError: LocalizedError {
    case batteryUnavailable

    var errorDescription: String? {
        switch self {
        case .batteryUnavailable:
            return "No AppleSmartBattery service is available on this Mac."
        }
    }
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published var snapshot: BatterySnapshot?
    @Published var history: [BatteryHistoryPoint] = []
    @Published var errorMessage: String?

    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: Duration = .seconds(1)
    private let historyWindow: TimeInterval = 60 * 5

    func start() {
        guard refreshTask == nil else { return }

        refresh()

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: refreshInterval)
                refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit {
        refreshTask?.cancel()
    }

    private func refresh() {
        do {
            let nextSnapshot = try BatteryReader.readSnapshot()
            snapshot = nextSnapshot
            errorMessage = nil
            appendHistoryPoint(for: nextSnapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendHistoryPoint(for snapshot: BatterySnapshot) {
        history.append(
            BatteryHistoryPoint(
                timestamp: snapshot.timestamp,
                netFlowMilliAmps: snapshot.netFlowMilliAmps
            )
        )

        let cutoff = Date().addingTimeInterval(-historyWindow)
        history.removeAll { $0.timestamp < cutoff }
    }
}

enum BatteryReader {
    static func readSnapshot() throws -> BatterySnapshot {
        guard let properties = appleSmartBatteryProperties() else {
            throw BatteryReaderError.batteryUnavailable
        }

        let currentCapacityMah = signedInt(properties["AppleRawCurrentCapacity"])
            ?? signedInt(properties["CurrentCapacity"])
            ?? 0

        let maxCapacityMah = max(
            signedInt(properties["AppleRawMaxCapacity"])
                ?? signedInt(properties["MaxCapacity"])
                ?? currentCapacityMah,
            currentCapacityMah
        )

        let designCapacityMah = max(
            signedInt(properties["DesignCapacity"]) ?? maxCapacityMah,
            maxCapacityMah
        )

        let percentage = {
            let directPercentage = signedInt(properties["CurrentCapacity"]) ?? 0
            if (0...100).contains(directPercentage) {
                return directPercentage
            }

            guard maxCapacityMah > 0 else { return 0 }
            return Int((Double(currentCapacityMah) / Double(maxCapacityMah) * 100).rounded())
        }()

        let externalConnected = boolValue(properties["ExternalConnected"])
            ?? boolValue(properties["AppleRawExternalConnected"])
            ?? false
        let isCharging = boolValue(properties["IsCharging"]) ?? false
        let cycleCount = signedInt(properties["CycleCount"]) ?? 0
        let amperageMilliAmps = signedInt(properties["InstantAmperage"])
            ?? signedInt(properties["Amperage"])
            ?? 0
        let voltageMilliVolts = signedInt(properties["Voltage"])
            ?? signedInt(properties["AppleRawBatteryVoltage"])
            ?? 0
        let temperatureCelsius = signedInt(properties["Temperature"]).map { Double($0) / 100.0 }
        let adapterWatts = adapterWatts(from: properties)
        let batteryPowerWatts: Double? = voltageMilliVolts == 0
            ? nil
            : Double(amperageMilliAmps * voltageMilliVolts) / 1_000_000.0
        let chargingSpeedMahPerHour = max(amperageMilliAmps, 0)
        let consumptionMahPerHour = max(-amperageMilliAmps, 0)
        let emptyCapacityMah = max(maxCapacityMah - currentCapacityMah, 0)
        let healthPercent = designCapacityMah > 0
            ? (Double(maxCapacityMah) / Double(designCapacityMah)) * 100
            : 0

        return BatterySnapshot(
            timestamp: Date(),
            percentage: percentage,
            stateDescription: stateDescription(externalConnected: externalConnected, isCharging: isCharging, flow: amperageMilliAmps),
            externalConnected: externalConnected,
            isCharging: isCharging,
            currentCapacityMah: currentCapacityMah,
            maxCapacityMah: maxCapacityMah,
            designCapacityMah: designCapacityMah,
            emptyCapacityMah: emptyCapacityMah,
            cycleCount: cycleCount,
            healthPercent: healthPercent,
            adapterWatts: adapterWatts,
            batteryPowerWatts: batteryPowerWatts,
            netFlowMilliAmps: amperageMilliAmps,
            chargingSpeedMahPerHour: chargingSpeedMahPerHour,
            consumptionMahPerHour: consumptionMahPerHour,
            temperatureCelsius: temperatureCelsius
        )
    }

    private static func appleSmartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &unmanagedProperties, kCFAllocatorDefault, 0)

        guard result == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        return properties
    }

    private static func adapterWatts(from properties: [String: Any]) -> Double? {
        if let adapter = properties["AdapterDetails"] as? [String: Any],
           let watts = signedInt(adapter["Watts"]) {
            return Double(watts)
        }

        if let rawAdapters = properties["AppleRawAdapterDetails"] as? [Any] {
            for rawAdapter in rawAdapters {
                if let adapter = rawAdapter as? [String: Any],
                   let watts = signedInt(adapter["Watts"]) {
                    return Double(watts)
                }
            }
        }

        return nil
    }

    private static func signedInt(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return Int(Int64(bitPattern: number.uint64Value))
        case let value as Int:
            return value
        case let value as Int64:
            return Int(value)
        case let value as UInt64:
            return Int(Int64(bitPattern: value))
        case let text as String:
            if let signed = Int(text) {
                return signed
            }
            if let unsigned = UInt64(text) {
                return Int(Int64(bitPattern: unsigned))
            }
            return nil
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let text as String:
            switch text.lowercased() {
            case "yes", "true", "1":
                return true
            case "no", "false", "0":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func stateDescription(externalConnected: Bool, isCharging: Bool, flow: Int) -> String {
        if externalConnected && isCharging {
            return "AC attached • Charging"
        }
        if externalConnected && flow < 0 {
            return "AC attached • Not charging"
        }
        if externalConnected {
            return "AC attached • Holding level"
        }
        return "Running on battery"
    }
}
