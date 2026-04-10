import Charts
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: BatteryMonitor
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    private let cardColumns = [
        GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 18)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.11, blue: 0.10),
                    Color(red: 0.08, green: 0.16, blue: 0.17),
                    Color(red: 0.15, green: 0.09, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let snapshot = monitor.snapshot {
                        header(snapshot: snapshot)
                        historySection
                        metricsGrid(snapshot: snapshot)
                    } else if let errorMessage = monitor.errorMessage {
                        fallbackMessage(title: "Battery data unavailable", message: errorMessage)
                    } else {
                        fallbackLoading
                    }
                }
                .padding(28)
            }
        }
    }

    private func header(snapshot: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image("GooseLogo")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("GooseBattery")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Realtime battery charging speed, consumption, health, and raw mAh capacity.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    HStack(spacing: 10) {
                        StatusPill(title: snapshot.stateDescription, tint: snapshot.externalConnected ? .mint : .orange)
                        StatusPill(title: "Updated \(snapshot.timestamp.formatted(date: .omitted, time: .standard))", tint: .white.opacity(0.2))
                    }

                    MenuBarToggleCard(isOn: $showMenuBarExtra)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 12) {
                    AnimatedGooseHero(snapshot: snapshot)
                        .frame(width: 290, height: 210)

                    Text(snapshot.isCharging ? "Battery is actively charging" : "Battery flow is live")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            CapacityBar(snapshot: snapshot)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Continuous battery flow")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Positive values mean charge is flowing into the battery. Negative values mean the battery is supplying the system.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))

            Chart(monitor.history) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Net Flow", point.netFlowMilliAmps)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.30),
                            Color.cyan.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Net Flow", point.netFlowMilliAmps)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.cyan)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartYScale(domain: flowDomain)
            .frame(height: 240)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func metricsGrid(snapshot: BatterySnapshot) -> some View {
        LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 18) {
            MetricCard(
                title: "Charging Speed",
                value: formatInteger(snapshot.chargingSpeedMahPerHour),
                unit: "mAh/h",
                accent: .green,
                note: snapshot.chargingSpeedMahPerHour > 0 ? "Current flowing into the pack" : "No active charging current"
            )

            MetricCard(
                title: "Consumption",
                value: formatInteger(snapshot.consumptionMahPerHour),
                unit: "mAh/h",
                accent: .orange,
                note: snapshot.consumptionMahPerHour > 0 ? "Battery drain at this instant" : "No drain reported right now"
            )

            MetricCard(
                title: "Adapter Input",
                value: formatOptional(snapshot.adapterWatts),
                unit: "W",
                accent: .mint,
                note: "Detected charger capability"
            )

            MetricCard(
                title: "Battery Power",
                value: formatSigned(snapshot.batteryPowerWatts),
                unit: "W",
                accent: snapshot.netFlowMilliAmps >= 0 ? .cyan : .pink,
                note: "Voltage x live battery current"
            )

            MetricCard(
                title: "Battery Health",
                value: formatDecimal(snapshot.healthPercent),
                unit: "%",
                accent: .teal,
                note: "\(formatInteger(snapshot.maxCapacityMah)) of \(formatInteger(snapshot.designCapacityMah)) mAh design capacity"
            )

            MetricCard(
                title: "Filled",
                value: formatInteger(snapshot.currentCapacityMah),
                unit: "mAh",
                accent: .blue,
                note: "Raw charge currently stored"
            )

            MetricCard(
                title: "Empty",
                value: formatInteger(snapshot.emptyCapacityMah),
                unit: "mAh",
                accent: .purple,
                note: "Remaining room before full"
            )

            MetricCard(
                title: "Max Capacity",
                value: formatInteger(snapshot.maxCapacityMah),
                unit: "mAh",
                accent: .indigo,
                note: "Current full-charge capacity"
            )

            MetricCard(
                title: "Design Capacity",
                value: formatInteger(snapshot.designCapacityMah),
                unit: "mAh",
                accent: .yellow,
                note: "Factory battery rating"
            )

            MetricCard(
                title: "Net Flow",
                value: formatSigned(Double(snapshot.netFlowMilliAmps)),
                unit: "mAh/h",
                accent: snapshot.netFlowMilliAmps >= 0 ? .green : .orange,
                note: "Same live current expressed as capacity rate"
            )

            MetricCard(
                title: "Cycle Count",
                value: formatInteger(snapshot.cycleCount),
                unit: "cycles",
                accent: .gray,
                note: "Total recorded charge cycles"
            )

            MetricCard(
                title: "Temperature",
                value: formatOptional(snapshot.temperatureCelsius),
                unit: "°C",
                accent: .red,
                note: "Battery temperature sensor"
            )
        }
    }

    private func fallbackMessage(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var fallbackLoading: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .tint(.white)

            Text("Reading live battery data...")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var flowDomain: ClosedRange<Double> {
        let values = monitor.history.map { Double($0.netFlowMilliAmps) }
        let maxMagnitude = max(values.map(\.magnitude).max() ?? 120, 120)
        return -(maxMagnitude * 1.2)...(maxMagnitude * 1.2)
    }

    private func formatInteger(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func formatDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private func formatOptional(_ value: Double?) -> String {
        guard let value else { return "—" }
        return formatDecimal(value)
    }

    private func formatSigned(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(
            .number
                .sign(strategy: .always(includingZero: false))
                .precision(.fractionLength(2))
        )
    }
}

private struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.22))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.55), lineWidth: 1)
            )
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let accent: Color
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.92))
            }

            Text(note)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct MenuBarToggleCard: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu bar widget")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Keep GooseBattery pinned in the menu bar for quick battery stats.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .toggleStyle(.switch)
        .tint(.mint)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.18))
        )
    }
}

private struct CapacityBar: View {
    let snapshot: BatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Filled \(snapshot.currentCapacityMah.formatted()) mAh")
                Spacer()
                Text("Empty \(snapshot.emptyCapacityMah.formatted()) mAh")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * snapshot.capacityFraction)
                }
            }
            .frame(height: 26)
        }
    }
}
