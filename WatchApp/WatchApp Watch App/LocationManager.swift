import Foundation
import CoreLocation
import Combine
import MapKit

// Custom Error Enum
enum LocationManagerError: Error {
    case locationServicesDisabled
    case locationAccessDenied
    case locationAccessRestricted
    case locationPermissionNotDetermined
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    // Published properties
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationError: LocationManagerError?
    @Published var isLocationAvailable = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    
    var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        configureLocationManager()
    }
    
    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        
        // Check background mode configuration
        if let backgroundModes = Bundle.main.infoDictionary?["WKBackgroundModes"] as? [String],
           backgroundModes.contains("location") {
            print("Background location mode configured")
        } else {
            print("Warning: Background location mode not configured in Info.plist")
        }
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("Requesting location authorization...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationTracking()
        case .denied:
            locationError = .locationAccessDenied
        case .restricted:
            locationError = .locationAccessRestricted
        @unknown default:
            break
        }
    }
    
    func startLocationTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = .locationServicesDisabled
            return
        }
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            requestLocationPermission()
        }
    }
    
    func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              -location.timestamp.timeIntervalSinceNow < 10.0 else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
            self.isLocationAvailable = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = .locationServicesDisabled
            self.isLocationAvailable = false
            print("Location error: \(error.localizedDescription)")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationTracking()
            case .denied:
                self.isLocationAvailable = false
                self.locationError = .locationAccessDenied
            case .restricted:
                self.isLocationAvailable = false
                self.locationError = .locationAccessRestricted
            case .notDetermined:
                self.requestLocationPermission()
            @unknown default:
                break
            }
        }
    }
    
    func getFormattedLocation() -> String {
        guard let location = currentLocation else {
            return "Location Unavailable"
        }
        return String(format: "Lat: %.6f, Lon: %.6f", location.latitude, location.longitude)
    }
    
    // Computed property for MKCoordinateRegion
    func getRegion() -> MKCoordinateRegion {
        guard let currentLocation = currentLocation else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default SF coordinates
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        
        return MKCoordinateRegion(
            center: currentLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}
