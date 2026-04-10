import AppKit
import SwiftUI

struct AnimatedGooseHero: View {
    let snapshot: BatterySnapshot

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let bob = sin(t * 1.6) * 6
            let wingLift = sin(t * 3.2) * 10
            let blinkClosed = abs(sin(t * 0.85)) > 0.94

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.22, blue: 0.23),
                                Color(red: 0.09, green: 0.12, blue: 0.22),
                                Color(red: 0.20, green: 0.13, blue: 0.27)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.cyan.opacity(0.16))
                    .frame(width: 144, height: 144)
                    .offset(x: -56, y: -26)
                    .blur(radius: 8)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 136, height: 82)
                    .offset(x: 66, y: -34)

                AnimatedGooseMark(wingLift: wingLift, blinkClosed: blinkClosed)
                    .frame(width: 180, height: 150)
                    .offset(x: -38, y: bob)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(snapshot.percentage)%")
                        .font(.system(size: 66, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(snapshot.netFlowMilliAmps >= 0 ? "Charging goose" : "Cruising on battery")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(22)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

struct MenuBarPanel: View {
    @ObservedObject var monitor: BatteryMonitor
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("GooseLogo")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("GooseBattery")
                        .font(.system(size: 15, weight: .bold, design: .rounded))

                    Text(monitor.snapshot?.stateDescription ?? "Reading battery...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot = monitor.snapshot {
                HStack(spacing: 12) {
                    MenuMetric(title: "Battery", value: "\(snapshot.percentage)%")
                    MenuMetric(title: "Charge", value: "\(snapshot.chargingSpeedMahPerHour.formatted()) mAh/h")
                    MenuMetric(title: "Drain", value: "\(snapshot.consumptionMahPerHour.formatted()) mAh/h")
                }

                HStack(spacing: 12) {
                    MenuMetric(title: "Health", value: "\(snapshot.healthPercent.formatted(.number.precision(.fractionLength(1))))%")
                    MenuMetric(title: "Filled", value: "\(snapshot.currentCapacityMah.formatted()) mAh")
                }
            } else if let error = monitor.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Divider()

            Button("Open Dashboard") {
                openWindow(id: "dashboard")
            }

            Button(showMenuBarExtra ? "Hide Menu Bar Widget" : "Show Menu Bar Widget") {
                showMenuBarExtra.toggle()
            }

            Button("Quit GooseBattery") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

struct MenuBarLabel: View {
    let snapshot: BatterySnapshot?

    var body: some View {
        HStack(spacing: 5) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)

            Text(snapshot.map { "\($0.percentage)%" } ?? "--")
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }
}

private struct AnimatedGooseMark: View {
    let wingLift: Double
    let blinkClosed: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.95, green: 0.97, blue: 1.0))
                .frame(width: 116, height: 80)
                .offset(x: -8, y: 22)

            Ellipse()
                .fill(Color(red: 0.80, green: 0.89, blue: 0.94))
                .frame(width: 66, height: 42)
                .rotationEffect(.degrees(-22 + wingLift))
                .offset(x: -20, y: 20)

            Capsule(style: .continuous)
                .fill(Color.white)
                .frame(width: 26, height: 92)
                .rotationEffect(.degrees(-10))
                .offset(x: 30, y: -10)

            Circle()
                .fill(Color.white)
                .frame(width: 42, height: 42)
                .offset(x: 42, y: -52)

            Triangle()
                .fill(Color(red: 0.96, green: 0.58, blue: 0.18))
                .frame(width: 22, height: 18)
                .rotationEffect(.degrees(12))
                .offset(x: 62, y: -50)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.black.opacity(0.75))
                .frame(width: 8, height: blinkClosed ? 2 : 8)
                .offset(x: 44, y: -54)

            Triangle()
                .fill(Color.white)
                .frame(width: 22, height: 20)
                .rotationEffect(.degrees(-14))
                .offset(x: -62, y: 20)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 14)
    }
}

private struct MenuMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
