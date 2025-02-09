import SwiftUI
import WatchKit
import CoreLocation
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var proximityManager = ProximityManager()
    @StateObject private var healthManager = HealthManager()

    var body: some View {
        TabView {
            LocationView(locationManager: locationManager)
                .tabItem {
                    Label("Location", systemImage: "location.fill")
                }

            SafeRouteView()
                .tabItem {
                    Label("Safe Route", systemImage: "map.fill")
                }

            SOSView()
                .tabItem {
                    Label("SOS", systemImage: "exclamationmark.triangle.fill")
                }
            
            FindChildView()
                .tabItem {
                    Label("Find My Child", systemImage: "location.fill")
                }

            NearbyDevicesView(proximityManager: proximityManager)
                .tabItem {
                    Label("Nearby", systemImage: "person.2.fill")
                }

            HealthView(healthManager: healthManager)
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }
        }
    }
}

// MARK: - Location View
struct LocationView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var locationName: String = "Fetching location..."

    var body: some View {
        VStack {
            Text("Current Location")
                .font(.headline)
                .padding(.top)

            WatchMapView(coordinate: locationManager.currentLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0))
                .frame(height: 120)
                .cornerRadius(10)
                .padding(.vertical, 5)

            Text(locationName)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()
                .onAppear {
                    reverseGeocode()
                }
        }
    }

    private func reverseGeocode() {
        guard let location = locationManager.currentLocation else { return }
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first, error == nil {
                    locationName = placemark.name ?? placemark.locality ?? "Unknown Location"
                } else {
                    locationName = "Unable to fetch location"
                }
            }
        }
    }
}

// MARK: - WatchOS Map
struct WatchMapView: WKInterfaceObjectRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeWKInterfaceObject(context: Context) -> WKInterfaceMap {
        return WKInterfaceMap()
    }

    func updateWKInterfaceObject(_ map: WKInterfaceMap, context: Context) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        map.setRegion(region)
        map.addAnnotation(coordinate, with: .red)
    }
}

// MARK: - Safe Route View
struct EnhancedSafeRouteView: View {
    @State private var region = MKCoordinateRegion()
    @State private var reportedCases: [ReportedCase] = []
    @State private var optimalRoute: [CLLocationCoordinate2D] = []
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var destination: CLLocationCoordinate2D?
    @State private var showDestinationPicker = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    private let locationManager = CLLocationManager()

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: reportedCases) { caseItem in
                MapAnnotation(coordinate: caseItem.location) {
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 10, height: 10)
                }
            }
            .overlay(RouteOverlay(route: optimalRoute))
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                setupLocation()
                fetchReportedCases()
            }

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        showDestinationPicker = true
                    }) {
                        Text(destination == nil ? "Set Destination" : "Change Destination")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if let start = userLocation, let end = destination {
                            calculateSafeRoute(from: start, to: end)
                        } else {
                            alertMessage = "Please set a destination first."
                            showAlert = true
                        }
                    }) {
                        Text("Find Safe Route")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            DestinationPicker(destination: $destination)
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    func setupLocation() {
        locationManager.delegate = LocationDelegate { location in
            DispatchQueue.main.async {
                self.userLocation = location
                self.region = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func fetchReportedCases() {
        self.reportedCases = [
            ReportedCase(location: CLLocationCoordinate2D(latitude: 37.7833, longitude: -122.4080)),
            ReportedCase(location: CLLocationCoordinate2D(latitude: 37.7820, longitude: -122.4070))
        ]
    }

    func calculateSafeRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        let graph = RouteGraph()
        let route = graph.findOptimalPath(from: start, to: end, avoiding: reportedCases.map { $0.location })
        DispatchQueue.main.async {
            self.optimalRoute = route
        }
    }
}

// MARK: - Destination Picker
struct DestinationPicker: View {
    @Binding var destination: CLLocationCoordinate2D?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Destination")) {
                    Button("San Francisco Ferry Building") {
                        destination = CLLocationCoordinate2D(latitude: 37.7956, longitude: -122.3934)
                    }
                    Button("Golden Gate Bridge") {
                        destination = CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
                    }
                    Button("Union Square") {
                        destination = CLLocationCoordinate2D(latitude: 37.7877, longitude: -122.4075)
                    }
                }
            }
            .navigationTitle("Set Destination")
        }
    }
}


// MARK: - Nearby Devices View
struct NearbyDevicesView: View {
    @ObservedObject var proximityManager: ProximityManager

    var body: some View {
        VStack {
            Text("Nearby Devices")
                .font(.headline)
                .padding(.top)

            ScrollView {
                VStack(spacing: 15) {
                    ForEach(proximityManager.nearbyDevices, id: \.self) { device in
                        Button(action: {
                            handleDeviceSelection(deviceName: device)
                        }) {
                            Text(device)
                                .padding()
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }

            if proximityManager.nearbyDevices.isEmpty {
                Text("Scanning...")
                    .foregroundColor(.gray)
                    .font(.title3)
                    .padding()
            }

            if let displayMessage = proximityManager.displayMessage {
                Text(displayMessage)
                    .padding()
                    .font(.title3)
                    .foregroundColor(.green)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(12)
            }
        }
        .onAppear {
            proximityManager.startScanning()
        }
    }

    func handleDeviceSelection(deviceName: String) {
        var message = ""

        if deviceName.lowercased().contains("ultra 2") {
            message = "Virat is hanging out with Luv"
        } else if deviceName.lowercased().contains("series 10") {
            message = "Luv is hanging out with Virat"
        }

        proximityManager.displayMessage = message
        proximityManager.sendNotification(for: deviceName)
    }
}

// MARK: - Health View
struct HealthView: View {
    @ObservedObject var healthManager: HealthManager

    var body: some View {
        VStack {
            Text("Health Metrics")
                .font(.headline)
                .padding(.top)

            ScrollView {
                VStack(spacing: 20) {
                    MetricCard(title: "Heart Rate", value: "\(healthManager.heartRate1) BPM", icon: "heart.fill")
                    MetricCard(title: "Steps", value: "\(healthManager.steps1)", icon: "figure.walk")
                    MetricCard(title: "Active Calories", value: healthManager.activeCalories, icon: "flame.fill")
                    MetricCard(title: "Oxygen Saturation", value: healthManager.oxygenSaturation, icon: "lungs.fill")
                }
                .padding()
            }
        }
        .onAppear {
            healthManager.startSimulation()
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            Text(value)
                .font(.title)
                .bold()
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}

struct FindChildView: View {
    @StateObject private var locationManager = LocationManager()
    
    // Target Location (Child's destination)
    private let targetLocation = CLLocationCoordinate2D(latitude: 18.45748, longitude: 73.85260)
    
    @State private var region: MKCoordinateRegion
    @State private var locationName: String = "Fetching child's location..."
    @State private var showFullMap: Bool = false
    @State private var distance: Double = 0
    
    init() {
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 18.45748, longitude: 73.85260),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with map toggle
            HStack {
                Text("Find My Child")
                    .font(.title3)
                    .bold()
                Spacer()
                if locationManager.currentLocation != nil {
                    Button(action: { showFullMap.toggle() }) {
                        Image(systemName: "map")
                            .font(.title3)
                    }
                }
            }
            .padding(.horizontal)
            
            if let location = locationManager.currentLocation {
                // Main content
                ScrollView {
                    VStack(spacing: 16) {
                        // Preview Map
                        WatchMapView(coordinate: location)
                            .frame(height: 120)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        // Location Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Location")
                                .font(.headline)
                            Text(locationName)
                                .font(.subheadline)
                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        // Navigation Card
                        NavigationInfoView(
                            currentLocation: location,
                            targetLocation: targetLocation,
                            distance: calculateDistance(from: location)
                        )
                        .padding(.horizontal)
                        
                        // Detailed Map
                        Map(coordinateRegion: $region, annotationItems: getAnnotations(from: location)) { annotation in
                            MapAnnotation(coordinate: annotation.coordinate) {
                                NavigationArrow(direction: annotation.direction)
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            } else {
                Spacer()
                ProgressView()
                Text("Locating child...")
                    .foregroundColor(.secondary)
                    .padding(.top)
                Spacer()
            }
        }
        .sheet(isPresented: $showFullMap) {
            FullMapView(
                region: $region,
                currentLocation: locationManager.currentLocation ?? targetLocation,
                targetLocation: targetLocation
            )
        }
        .onAppear {
            locationManager.startLocationTracking()
        }
        .onDisappear {
            locationManager.stopLocationTracking()
        }
        .onChange(of: locationManager.currentLocation) { newLocation in
            if let location = newLocation {
                updateRegion(with: location)
                reverseGeocode(location: location)
            }
        }
    }
    
    private func calculateDistance(from location: CLLocationCoordinate2D) -> Double {
        let currentLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let targetLoc = CLLocation(latitude: targetLocation.latitude, longitude: targetLocation.longitude)
        return currentLoc.distance(from: targetLoc)
    }
    
    private func updateRegion(with location: CLLocationCoordinate2D) {
        let midLat = (location.latitude + targetLocation.latitude) / 2
        let midLon = (location.longitude + targetLocation.longitude) / 2
        
        let latDelta = abs(location.latitude - targetLocation.latitude) * 1.5
        let lonDelta = abs(location.longitude - targetLocation.longitude) * 1.5
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.005, latDelta),
                longitudeDelta: max(0.005, lonDelta)
            )
        )
    }
    
    private func reverseGeocode(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first, error == nil {
                    var components: [String] = []
                    if let name = placemark.name { components.append(name) }
                    if let locality = placemark.locality { components.append(locality) }
                    if let area = placemark.administrativeArea { components.append(area) }
                    locationName = components.joined(separator: ", ")
                } else {
                    locationName = "Unable to fetch location"
                }
            }
        }
    }
    
    private func getAnnotations(from currentLocation: CLLocationCoordinate2D) -> [NavigationAnnotation] {
        [NavigationAnnotation(
            coordinate: currentLocation,
            direction: calculateDirection(from: currentLocation, to: targetLocation)
        )]
    }
    
    private func calculateDirection(from currentLocation: CLLocationCoordinate2D, to targetLocation: CLLocationCoordinate2D) -> String {
        let bearing = calculateBearing(from: currentLocation, to: targetLocation)
        return getCardinalDirection(bearing: bearing)
    }
    
    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func getCardinalDirection(bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(round(bearing / 45)) % 8
        return directions[index]
    }
}

// MARK: - Supporting Views and Types

struct NavigationInfoView: View {
    let currentLocation: CLLocationCoordinate2D
    let targetLocation: CLLocationCoordinate2D
    let distance: Double
    
    var body: some View {
        VStack(spacing: 12) {
            let direction = calculateDirection()
            
            HStack {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(calculateBearing()))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(direction)
                    .font(.headline)
            }
            
            Text(formatDistance(distance))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    private func calculateDirection() -> String {
        let bearing = calculateBearing()
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        let index = Int(round(bearing / 45)) % 8
        return directions[index]
    }
    
    private func calculateBearing() -> Double {
        let lat1 = currentLocation.latitude * .pi / 180
        let lon1 = currentLocation.longitude * .pi / 180
        let lat2 = targetLocation.latitude * .pi / 180
        let lon2 = targetLocation.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f meters away", meters)
        } else {
            return String(format: "%.1f kilometers away", meters / 1000)
        }
    }
}

struct NavigationArrow: View {
    let direction: String
    
    var body: some View {
        Image(systemName: "location.north.fill")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundColor(.blue)
            .rotationEffect(rotationAngle)
            .background(
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
            )
            .shadow(radius: 2)
    }
    
    private var rotationAngle: Angle {
        let directions = ["N": 0.0, "NE": 45.0, "E": 90.0, "SE": 135.0,
                         "S": 180.0, "SW": 225.0, "W": 270.0, "NW": 315.0]
        return .degrees(directions[direction] ?? 0.0)
    }
}

struct NavigationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let direction: String
}

struct FullMapView: View {
    @Binding var region: MKCoordinateRegion
    let currentLocation: CLLocationCoordinate2D
    let targetLocation: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Location Map")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            
            // Map
            Map(coordinateRegion: $region, annotationItems: getAnnotations()) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    Circle()
                        .fill(place.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
        }
    }
    
    private func getAnnotations() -> [Place] {
        [
            Place(name: "Current", coordinate: currentLocation, color: .blue),
            Place(name: "Target", coordinate: targetLocation, color: .red)
        ]
    }
}



