//
//  MapViewController.swift
//  Feed Me
//
/// Copyright (c) 2017 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import GoogleMaps

class MapViewController: UIViewController {
  
	@IBOutlet weak var addressLabel: UILabel!
	@IBOutlet weak var mapView: GMSMapView!
	@IBOutlet private weak var mapCenterPinImage: UIImageView!
	@IBOutlet private weak var pinImageVerticalConstraint: NSLayoutConstraint!
	var searchedTypes = ["bakery", "bar", "cafe", "grocery_or_supermarket", "restaurant"]
  
	private let locationManager = CLLocationManager()
	
	private let dataProvider = GoogleDataProvider()
	private let searchRadius: Double = 1000
	
	
  override func viewDidLoad() {
    super.viewDidLoad()
	//
	locationManager.delegate = self as! CLLocationManagerDelegate
	locationManager.requestWhenInUseAuthorization()
	//
	mapView.delegate = self
	
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let navigationController = segue.destination as? UINavigationController,
      let controller = navigationController.topViewController as? TypesTableViewController else {
        return
    }
    controller.selectedTypes = searchedTypes
    controller.delegate = self
  }
	
	@IBAction func refreshPlaces(_ sender: Any) {
		searchNearbyPlaces(coordinate: mapView.camera.target)
	}
	
	private func searchNearbyPlaces(coordinate: CLLocationCoordinate2D) {
		mapView.clear()
		//
		dataProvider.fetchPlacesNearCoordinate(coordinate, radius: searchRadius, types: searchedTypes) { places in
			for place in places {
				let marker = PlaceMarker(place: place)
				marker.map = self.mapView
			}
		}
	}
	
	private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
		
		addressLabel.unlock()
		
		// 1
		let geocoder = GMSGeocoder()
		
		// 2
		geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
			guard let address = response?.firstResult(), let lines = address.lines else {
				return
			}
			
			// 3
			self.addressLabel.text = lines.joined(separator: "\n")
			
			// 1
			let labelHeight = self.addressLabel.intrinsicContentSize.height
			self.mapView.padding = UIEdgeInsets(top: self.view.safeAreaInsets.top,
												left: 0,
												bottom: labelHeight,
												right: 0)

			// 4
			UIView.animate(withDuration: 0.25) {
				self.pinImageVerticalConstraint.constant =
					((labelHeight - self.view.safeAreaInsets.top) * 0.5)
				self.view.layoutIfNeeded()
			}
		}
	}

}

// MARK: - TypesTableViewControllerDelegate
extension MapViewController: TypesTableViewControllerDelegate {
  func typesController(_ controller: TypesTableViewController, didSelectTypes types: [String]) {
    searchedTypes = controller.selectedTypes.sorted()
    dismiss(animated: true)
	//
	searchNearbyPlaces(coordinate: mapView.camera.target)
  }
}

extension MapViewController: CLLocationManagerDelegate {
	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		//Here you verify the user has granted you permission while the app is in use.
		guard status == .authorizedWhenInUse else {
			return
		}
		// Once permissions have been established, ask the location manager for updates on the user’s location.
		locationManager.startUpdatingLocation()
		
		mapView.isMyLocationEnabled = true
		mapView.settings.myLocationButton = true
	}
	
	// executes when the location manager receives new location data.
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.first else {
			return
		}
		
		mapView.camera = GMSCameraPosition(target: location.coordinate, zoom: 15.0, bearing: 0, viewingAngle: 0)
		
		//Tell locationManager you’re no longer interested in updates;
		// you don’t want to follow a user around
		// as their initial location is enough for you to work with.
		locationManager.stopUpdatingLocation()
		//
		searchNearbyPlaces(coordinate: location.coordinate)
	}
}

// MARK: - GMSMapViewDelegate
extension MapViewController: GMSMapViewDelegate {
	func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
		reverseGeocodeCoordinate(position.target)
	}
	
	func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
		addressLabel.lock()
		//
		if gesture {
			mapCenterPinImage.fadeIn(0.25)
			mapView.selectedMarker = nil
		}
	}
	
	func mapView(_ mapView: GMSMapView, markerInfoContents marker: GMSMarker) -> UIView? {
		// 1
		guard let placeMarker = marker as? PlaceMarker else {
			return nil
		}
		
		// 2
		guard let infoView = UIView.viewFromNibName("MarkerInfoView") as? MarkerInfoView else {
			return nil
		}
		// 3
		infoView.nameLabel.text = placeMarker.place.name
		
		// 4
		if let photo = placeMarker.place.photo {
			infoView.placePhoto.image = photo
		} else {
			infoView.placePhoto.image = UIImage(named: "generic")
		}
		
		return infoView
	}
	
	func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
		mapCenterPinImage.fadeOut(0.25)
		return false
	}
	
	func didTapMyLocationButton(for mapView: GMSMapView) -> Bool {
		mapCenterPinImage.fadeIn(0.25)
		mapView.selectedMarker = nil
		return false
	}
}
