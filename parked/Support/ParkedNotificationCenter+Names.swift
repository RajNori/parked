//
//  ParkedNotificationCenter+Names.swift
//  parked
//

import Foundation

extension Notification.Name {
    /// Posted when a meter expiry fires while foregrounded (system banner suppressed).
    static let parkedMeterExpired = Notification.Name("com.parked.app.meterExpired")
}

enum ParkedMeterExpiredUserInfoKey {
    static let spotId = "spotId"
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let address = "address"
}
