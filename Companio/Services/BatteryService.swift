import Foundation
import UIKit
import Combine

// MARK: - BatteryService

/// Monitors device battery level and charging state.
/// Publishes events when battery drops to low threshold or charging begins/ends.
final class BatteryService: ObservableObject {

    static let shared = BatteryService()

    // MARK: - Publishers

    /// Fires once when battery drops to or below the low threshold.
    let lowBatteryPublisher = PassthroughSubject<Double, Never>()

    /// Fires when charging state changes. `true` = plugged in, `false` = unplugged.
    let chargingStatePublisher = PassthroughSubject<Bool, Never>()

    // MARK: - Published State

    @Published private(set) var batteryLevel: Double = 1.0
    @Published private(set) var isCharging: Bool = false

    // MARK: - Configuration

    /// Battery percentage threshold considered "low" (0.0–1.0).
    let lowBatteryThreshold: Double = 0.20

    // MARK: - Private

    private var hasEmittedLowBattery = false
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Read initial state
        batteryLevel = Double(UIDevice.current.batteryLevel)
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full

        // Observe system notifications
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateBatteryLevel() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateChargingState() }
            .store(in: &cancellables)

        // Safety poll every 60s in case notifications are missed
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateBatteryLevel()
                self?.updateChargingState()
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Updates

    private func updateBatteryLevel() {
        let level = Double(UIDevice.current.batteryLevel)
        guard level >= 0 else { return } // -1 means unknown

        batteryLevel = level

        if level <= lowBatteryThreshold && !hasEmittedLowBattery && !isCharging {
            hasEmittedLowBattery = true
            lowBatteryPublisher.send(level)
        }

        // Reset the flag once battery recovers above threshold
        if level > lowBatteryThreshold {
            hasEmittedLowBattery = false
        }
    }

    private func updateChargingState() {
        let state = UIDevice.current.batteryState
        let nowCharging = state == .charging || state == .full
        let wasCharging = isCharging

        isCharging = nowCharging

        if nowCharging != wasCharging {
            chargingStatePublisher.send(nowCharging)
        }

        // If charging, clear the low battery flag so it can re-fire later if unplugged
        if nowCharging {
            hasEmittedLowBattery = false
        }
    }
}
