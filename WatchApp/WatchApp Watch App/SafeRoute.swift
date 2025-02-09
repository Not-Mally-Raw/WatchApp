import SwiftUI
import MapKit
import CoreLocation

// MARK: - Extensions
extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Models
struct PredefinedLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct ReportedCase: Identifiable {
    let id = UUID()
    let location: CLLocationCoordinate2D
}

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: LocationType
    
    enum LocationType {
        case danger
        case destination
    }
}

// MARK: - LocationDelegate
class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onUpdate: (CLLocationCoordinate2D) -> Void
    
    init(onUpdate: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            onUpdate(location.coordinate)
        }
    }
}

// MARK: - Main View
struct SafeRouteView: View {
    // MARK: - State
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 18.457905, longitude: 73.850494),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var reportedCases: [ReportedCase] = []
    @State private var optimalRoute: [CLLocationCoordinate2D] = []
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var selectedDestination: PredefinedLocation?
    @State private var showLocationPicker = false
    
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    
    private let predefinedLocations = [
        PredefinedLocation(name: "Home", coordinate: CLLocationCoordinate2D(latitude: 18.4586, longitude: 73.8332)),
        PredefinedLocation(name: "Playfield", coordinate: CLLocationCoordinate2D(latitude: 18.4552, longitude: 73.8412)),
        PredefinedLocation(name: "School", coordinate: CLLocationCoordinate2D(latitude: 18.4598, longitude: 73.8356))
    ]
    
    private var mapLocations: [MapLocation] {
        var locations = reportedCases.map {
            MapLocation(coordinate: $0.location, type: .danger)
        }
        
        if let destination = selectedDestination {
            locations.append(MapLocation(coordinate: destination.coordinate, type: .destination))
        }
        
        return locations
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    Map(
                        coordinateRegion: $region,
                        showsUserLocation: true,
                        annotationItems: mapLocations
                    ) { location in
                        MapMarker(
                            coordinate: location.coordinate,
                            tint: location.type == .danger ? .red : .green
                        )
                    }
                    
                    if !optimalRoute.isEmpty {
                        RouteOverlay(route: optimalRoute)
                    }
                }
                .frame(height: geometry.size.height * 0.6)
                
                VStack(spacing: 10) {
                    Button(action: { showLocationPicker = true }) {
                        Text(selectedDestination?.name ?? "Select Destination")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    if selectedDestination != nil {
                        Button(action: findSafeRoute) {
                            Text("Find Safe Route")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                locations: predefinedLocations,
                selectedLocation: $selectedDestination
            )
        }
        .onAppear {
            setupLocation()
            fetchReportedCases()
        }
    }
    
    // MARK: - Methods
    private func setupLocation() {
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
    
    private func fetchReportedCases() {
        // Simulated data - replace with actual API call
        self.reportedCases = [
            ReportedCase(location: CLLocationCoordinate2D(latitude: 18.45568, longitude: 73.84165)),
            ReportedCase(location: CLLocationCoordinate2D(latitude: 18.45586, longitude: 73.84382))
        ]
    }
    
    private func findSafeRoute() {
        guard let start = userLocation, let destination = selectedDestination else { return }
        let graph = RouteGraph()
        let route = graph.findOptimalPath(
            from: start,
            to: destination.coordinate,
            avoiding: reportedCases.map { $0.location }
        )
        
        DispatchQueue.main.async {
            self.optimalRoute = route
        }
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    let locations: [PredefinedLocation]
    @Binding var selectedLocation: PredefinedLocation?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List(locations) { location in
            Button(action: {
                selectedLocation = location
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(location.name)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Route Overlay
struct RouteOverlay: View {
    let route: [CLLocationCoordinate2D]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = route.map { coordinate in
                    CGPoint(
                        x: geometry.size.width * (coordinate.longitude + 180) / 360,
                        y: geometry.size.height * (90 - coordinate.latitude) / 180
                    )
                }
                if !points.isEmpty {
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}

// MARK: - Route Graph
class RouteGraph {
    private let gridStep = 0.0005 // Approximately 55 meters
    private let dangerRadius = 50.0 // meters
    
    func findOptimalPath(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        avoiding dangers: [CLLocationCoordinate2D]
    ) -> [CLLocationCoordinate2D] {
        var openSet: Set<CLLocationCoordinate2D> = [start]
        var closedSet: Set<CLLocationCoordinate2D> = []
        var cameFrom: [CLLocationCoordinate2D: CLLocationCoordinate2D] = [:]
        var gScore: [CLLocationCoordinate2D: Double] = [start: 0]
        var fScore: [CLLocationCoordinate2D: Double] = [start: heuristic(start, end)]
        
        while !openSet.isEmpty {
            let current = openSet.min(by: { fScore[$0, default: .infinity] < fScore[$1, default: .infinity] })!
            
            if distance(from: current, to: end) < gridStep {
                return reconstructPath(cameFrom: cameFrom, current: current)
            }
            
            openSet.remove(current)
            closedSet.insert(current)
            
            for neighbor in getNeighbors(of: current) {
                if closedSet.contains(neighbor) || isNearDanger(neighbor, dangers: dangers) {
                    continue
                }
                
                let tentativeGScore = gScore[current, default: .infinity] + distance(from: current, to: neighbor)
                
                if !openSet.contains(neighbor) {
                    openSet.insert(neighbor)
                } else if tentativeGScore >= gScore[neighbor, default: .infinity] {
                    continue
                }
                
                cameFrom[neighbor] = current
                gScore[neighbor] = tentativeGScore
                fScore[neighbor] = tentativeGScore + heuristic(neighbor, end)
            }
        }
        
        // If no path found, return direct path
        return [start, end]
    }
    
    private func heuristic(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        return distance(from: a, to: b)
    }
    
    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB)
    }
    
    private func getNeighbors(of point: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        var neighbors: [CLLocationCoordinate2D] = []
        for deltaLat in [-gridStep, 0, gridStep] {
            for deltaLon in [-gridStep, 0, gridStep] {
                if deltaLat == 0 && deltaLon == 0 { continue }
                neighbors.append(CLLocationCoordinate2D(
                    latitude: point.latitude + deltaLat,
                    longitude: point.longitude + deltaLon
                ))
            }
        }
        return neighbors
    }
    
    private func isNearDanger(_ point: CLLocationCoordinate2D, dangers: [CLLocationCoordinate2D]) -> Bool {
        return dangers.contains { danger in
            distance(from: point, to: danger) < dangerRadius
        }
    }
    
    private func reconstructPath(cameFrom: [CLLocationCoordinate2D: CLLocationCoordinate2D], current: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        var path = [current]
        var node = current
        while let next = cameFrom[node] {
            path.insert(next, at: 0)
            node = next
        }
        return path
    }
}
