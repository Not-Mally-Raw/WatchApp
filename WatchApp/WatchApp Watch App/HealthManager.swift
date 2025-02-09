import Foundation
import HealthKit

class HealthManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()

    // Published Properties
    @Published var heartRate: String = "Loading..."
    @Published var heartRateVariation: String = "Loading..."
    @Published var activeCalories: String = "Loading..."
    @Published var steps: String = "Loading..."
    @Published var distance: String = "Loading..."
    @Published var oxygenSaturation: String = "Loading..."
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    // Authorization State
    enum AuthorizationStatus {
        case notDetermined, authorized, denied, restricted, notAvailable
    }

    override init() {
        super.init()
        requestHealthKitPermissions()
    }

    // MARK: - Request HealthKit Authorization
    private func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async { self.authorizationStatus = .notAvailable }
            print("HealthKit not available on this device")
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.authorizationStatus = .authorized
                    self?.fetchLatestHealthData()
                    self?.startAllMonitoring()
                } else {
                    self?.authorizationStatus = .denied
                    
                }
            }
        }
    }

    // MARK: - Fetch Latest Health Data
    private func fetchLatestHealthData() {
        fetchLatestSample(for: .heartRate, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] value in
            self?.heartRate = value.map { "\($0) BPM" } ?? "No Data"
        }
        fetchLatestSample(for: .activeEnergyBurned, unit: .kilocalorie()) { [weak self] value in
            self?.activeCalories = value.map { "\($0) kcal" } ?? "No Data"
        }
    }

    // MARK: - Start Real-Time Monitoring
    private func startAllMonitoring() {
        startMonitoring(for: .heartRate, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] value in
            let variation = Double.random(in: -5...5)
            let adjustedValue = max(value + variation, 40)
            self?.heartRate = String(format: "%.0f BPM", adjustedValue)
            self?.heartRateVariation = String(format: "Variation: %.0f BPM", variation)
        }
        startMonitoring(for: .activeEnergyBurned, unit: .kilocalorie()) { [weak self] value in
            self?.activeCalories = String(format: "%.1f kcal", value)
        }
    }
    @Published var heartRate1: Int = 75
    @Published var steps1: Int = 0
    private var timer: Timer?
    func startSimulation() {
            timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                self.simulateHeartRate()
                self.simulateSteps()
            }
        }
        
        private func simulateHeartRate() {
            let variation = Int.random(in: -5...5)
            let newHeartRate = max(60, min(120, heartRate1 + variation))
            DispatchQueue.main.async {
                self.heartRate1 = newHeartRate
            }
        }
        
        private func simulateSteps() {
            let stepIncrease = Int.random(in: 5...10)
            DispatchQueue.main.async {
                self.steps1 += stepIncrease
            }
        }

    // MARK: - Helper Functions for HealthKit Queries
    private func fetchLatestSample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                //print("No data for \(identifier.rawValue): \(error?.localizedDescription ?? \"Unknown error\")")
                completion(nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit))
        }

        healthStore.execute(query)
    }

    private func startMonitoring(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, updateHandler: @escaping (Double) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        let query = HKAnchoredObjectQuery(
            type: quantityType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { _, samples, _, _, _ in
            guard let latestSample = (samples as? [HKQuantitySample])?.last else { return }
            DispatchQueue.main.async {
                updateHandler(latestSample.quantity.doubleValue(for: unit))
            }
        }

        query.updateHandler = { _, samples, _, _, _ in
            guard let latestSample = (samples as? [HKQuantitySample])?.last else { return }
            DispatchQueue.main.async {
                updateHandler(latestSample.quantity.doubleValue(for: unit))
            }
        }

        healthStore.execute(query)
    }
}
