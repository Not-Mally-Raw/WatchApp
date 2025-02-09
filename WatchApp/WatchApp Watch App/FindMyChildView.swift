import SwiftUI
import MapKit

struct FindMyChildView: View {
    @StateObject private var locationManager = LocationManager()
    
    // Static parent's location (since you mentioned it should be static)
    private let parentLocation = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
    
    // Track map region
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    
    var body: some View {
        VStack {
            Text("Find My Parent")
                .font(.headline)
                .padding()

            Map(coordinateRegion: $region, annotationItems: getAnnotations()) { place in
                MapMarker(coordinate: place.coordinate, tint: place.color)
            }
            .frame(height: 300)
            .cornerRadius(10)
            .padding(.top, 10)
            
            // Navigation Instructions
            VStack(spacing: 15) {
                if let childLocation = locationManager.currentLocation {
                    let navigationInfo = calculateNavigationInfo(from: childLocation, to: parentLocation)
                    
                    Text("Distance: \(formatDistance(navigationInfo.distance))")
                        .font(.title3)
                        .bold()
                    
                    Text(navigationInfo.detailedDirections)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    ArrowView(direction: navigationInfo.direction)
                        .frame(width: 50, height: 50)
                } else {
                    Text("Locating you...")
                        .font(.title3)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding()
        }
        .onAppear {
            locationManager.startLocationTracking()
        }
        .onChange(of: locationManager.currentLocation) { _ in
            updateRegion()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAnnotations() -> [Place] {
        [
            Place(name: "Parent", coordinate: parentLocation, color: .red),
            Place(name: "You", coordinate: locationManager.currentLocation ?? parentLocation, color: .blue)
        ]
    }
    
    private struct NavigationInfo {
        let distance: CLLocationDistance
        let direction: String
        let detailedDirections: String
        let bearing: Double
    }
    
    private func calculateNavigationInfo(from childLocation: CLLocationCoordinate2D, to parentLocation: CLLocationCoordinate2D) -> NavigationInfo {
        let childLoc = CLLocation(latitude: childLocation.latitude, longitude: childLocation.longitude)
        let parentLoc = CLLocation(latitude: parentLocation.latitude, longitude: parentLocation.longitude)
        
        // Calculate distance
        let distance = childLoc.distance(from: parentLoc)
        
        // Calculate bearing
        let bearing = calculateBearing(from: childLocation, to: parentLocation)
        
        // Get cardinal direction
        let direction = getCardinalDirection(bearing: bearing)
        
        // Generate detailed directions
        let detailedDirections = generateDetailedDirections(distance: distance, bearing: bearing)
        
        return NavigationInfo(
            distance: distance,
            direction: direction,
            detailedDirections: detailedDirections,
            bearing: bearing
        )
    }
    
    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        
        return (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private func getCardinalDirection(bearing: Double) -> String {
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        let index = Int(round(bearing / 45)) % 8
        return directions[index]
    }
    
    private func generateDetailedDirections(distance: CLLocationDistance, bearing: Double) -> String {
        let cardinalDirection = getCardinalDirection(bearing: bearing)
        
        if distance < 10 {
            return "You're very close to your parent!"
        } else if distance < 50 {
            return "Walk \(cardinalDirection) for about \(formatDistance(distance))"
        } else {
            return "Head \(cardinalDirection) for \(formatDistance(distance))"
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(round(distance))) meters"
        } else {
            let kilometers = distance / 1000
            return String(format: "%.1f kilometers", kilometers)
        }
    }
    
    private func updateRegion() {
        guard let currentLocation = locationManager.currentLocation else { return }
        // Calculate the midpoint between parent and child
        let midLat = (currentLocation.latitude + parentLocation.latitude) / 2
        let midLon = (currentLocation.longitude + parentLocation.longitude) / 2
        
        // Calculate appropriate span to show both points
        let latDelta = abs(currentLocation.latitude - parentLocation.latitude) * 1.5
        let lonDelta = abs(currentLocation.longitude - parentLocation.longitude) * 1.5
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: max(0.005, latDelta), longitudeDelta: max(0.005, lonDelta))
        )
    }
}

// MARK: - Place Struct for Map Annotations
struct Place: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let color: Color
}

// MARK: - Enhanced Arrow View
struct ArrowView: View {
    var direction: String
    
    var body: some View {
        Image(systemName: arrowIcon(for: direction))
            .resizable()
            .scaledToFit()
            .foregroundColor(.blue)
            .rotationEffect(rotationAngle(for: direction))
    }
    
    private func arrowIcon(for direction: String) -> String {
        "arrow.up"
    }
    
    private func rotationAngle(for direction: String) -> Angle {
        switch direction {
        case "North": return .degrees(0)
        case "Northeast": return .degrees(45)
        case "East": return .degrees(90)
        case "Southeast": return .degrees(135)
        case "South": return .degrees(180)
        case "Southwest": return .degrees(225)
        case "West": return .degrees(270)
        case "Northwest": return .degrees(315)
        default: return .degrees(0)
        }
    }
}
