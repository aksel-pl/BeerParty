import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationTrackingService: NSObject, ObservableObject {
  @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
  @Published private(set) var lastLocation: CLLocation?

  var onLocationUpdate: ((CLLocation) -> Void)?

  private let manager = CLLocationManager()
  private var isTracking = false

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    manager.distanceFilter = 25
    manager.pausesLocationUpdatesAutomatically = true
    authorizationStatus = manager.authorizationStatus
  }

  func startTracking(allowsBackground: Bool) {
    manager.allowsBackgroundLocationUpdates = allowsBackground

    switch manager.authorizationStatus {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      if allowsBackground, manager.authorizationStatus == .authorizedWhenInUse {
        manager.requestAlwaysAuthorization()
      }
      manager.startUpdatingLocation()
      isTracking = true
    case .restricted, .denied:
      stopTracking()
    @unknown default:
      stopTracking()
    }
  }

  func stopTracking() {
    manager.stopUpdatingLocation()
    isTracking = false
  }
}

extension LocationTrackingService: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      authorizationStatus = manager.authorizationStatus
      if isTracking {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
          manager.startUpdatingLocation()
        case .restricted, .denied:
          stopTracking()
        case .notDetermined:
          break
        @unknown default:
          break
        }
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let latest = locations.last else { return }
    Task { @MainActor in
      lastLocation = latest
      onLocationUpdate?(latest)
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // Keep silent for transient location errors to avoid noisy UI.
  }
}
