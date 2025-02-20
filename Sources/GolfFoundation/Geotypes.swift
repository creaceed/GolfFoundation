/*
Copyright (c) 2025-present Creaceed SPRL and other GolfFoundation contributors.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright
	  notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.
	* Neither the name of Creaceed SPRL nor the
	  names of its contributors may be used to endorse or promote products
	  derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL CREACEED SPRL BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

public typealias LocationDegrees = Double
public struct LocationCoordinate2D: Codable, Hashable, Identifiable {
	public let id = UUID()
	public var latitude: LocationDegrees
	public var longitude: LocationDegrees
	
	public init(latitude: LocationDegrees, longitude: LocationDegrees) {
		self.latitude = latitude
		self.longitude = longitude
	}
	
	public static func interpolate(_ aloc: LocationCoordinate2D, _ bloc: LocationCoordinate2D, t: Double) -> LocationCoordinate2D {
		let omt = 1.0-t
		return .init(latitude: omt * aloc.latitude + t * bloc.latitude, longitude: omt * aloc.longitude + t * bloc.longitude)
	}
	
	
	// Codable
	private enum CodingKeys: String, CodingKey {
		case latitude
		case longitude
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(latitude, forKey: .latitude)
		try container.encode(longitude, forKey: .longitude)
	}
	
	public init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		let _latitude = try values.decode(Double.self, forKey: .latitude)
		let _longitude = try values.decode(Double.self, forKey: .longitude)
		
		self.init(latitude: _latitude, longitude: _longitude)
	}
	
	// Hashable
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(latitude)
		hasher.combine(longitude)
	}
	
	// Operators
	public static func + (left: Self, right: Self) -> Self {
		return .init(latitude: left.latitude + right.latitude, longitude: left.longitude + right.longitude)
	}
	public static func - (left: Self, right: Self) -> Self {
		return .init(latitude: left.latitude - right.latitude, longitude: left.longitude - right.longitude)
	}
	public static func * (left: Double, right: Self) -> Self {
		return .init(latitude: left * right.latitude, longitude: left * right.longitude)
	}
}

public struct LocationFrame {
	public var origin: LocationCoordinate2D { .init(latitude: latitude.lowerBound, longitude: longitude.lowerBound) } // minimum lat/long
	public var end: LocationCoordinate2D { .init(latitude: latitude.upperBound, longitude: longitude.upperBound) } // maximum lat/long ( >= origin)
	public var center: LocationCoordinate2D { .init(latitude: 0.5 * (latitude.lowerBound + latitude.upperBound), longitude: 0.5 * (longitude.lowerBound + longitude.upperBound)) }
	public var latitudeSpan: Double { return latitude.upperBound - latitude.lowerBound }
	public var longitudeSpan: Double { return longitude.upperBound - longitude.lowerBound }
	public var corners: [LocationCoordinate2D] {
		[
			origin,
			.init(latitude: origin.latitude, longitude: end.longitude),
			end,
			.init(latitude: end.latitude, longitude: origin.longitude)
		]
	}
	
	private(set) var latitude: ClosedRange<LocationDegrees>
	private(set) var longitude: ClosedRange<LocationDegrees>
	
	
	
//	public var standardized: Self {
//		return .init(,
//	}
	
	public static func union(_ lhs: LocationFrame?, _ rhs: LocationFrame?) -> LocationFrame? {
		if lhs == nil { return rhs }
		else if rhs == nil { return lhs }
		else { return lhs!.union(with: rhs!) }
	}
	public static func expanding(_ lhs: LocationFrame?, _ rhs: LocationCoordinate2D?) -> LocationFrame? {
		if lhs == nil { return nil }
		else if rhs == nil { return lhs }
		else { return lhs!.expanding(to: rhs!) }
	}
	
	public init(_ c1: LocationCoordinate2D, _ c2: LocationCoordinate2D) {
		let _min = LocationCoordinate2D(latitude: Swift.min(c1.latitude, c2.latitude), longitude: Swift.min(c1.longitude, c2.longitude))
		let _max = LocationCoordinate2D(latitude: Swift.max(c1.latitude, c2.latitude), longitude: Swift.max(c1.longitude, c2.longitude))
		
		latitude = _min.latitude ... _max.latitude
		longitude = _min.longitude ... _max.longitude
	}
	public init(latitude: ClosedRange<LocationDegrees>, longitude: ClosedRange<LocationDegrees>) {
		self.latitude = latitude
		self.longitude = longitude
	}
	
	public func intersects(_ r2: Self) -> Bool {
		latitude.overlaps(r2.latitude) && longitude.overlaps(r2.longitude)
	}
	
	public func union(with r2: Self) -> Self {
		let lat = min(latitude.lowerBound, r2.latitude.lowerBound) ... max(latitude.upperBound, r2.latitude.upperBound)
		let long = min(longitude.lowerBound, r2.longitude.lowerBound) ... max(longitude.upperBound, r2.longitude.upperBound)
		
		return .init(latitude: lat, longitude: long)
	}
	
	public func expanding(to: LocationCoordinate2D) -> Self {
		let lat = min(latitude.lowerBound, to.latitude) ... max(latitude.upperBound, to.latitude)
		let long = min(longitude.lowerBound, to.longitude) ... max(longitude.upperBound, to.longitude)
		
		return .init(latitude: lat, longitude: long)
	}
	
	public func intersection(with r2: Self) -> Self? {
		guard latitude.overlaps(r2.latitude) && longitude.overlaps(r2.longitude) else { return nil }
		
		let lat = latitude.clamped(to: r2.latitude)
		let long = longitude.clamped(to: r2.longitude)
		
		return Self(latitude: lat, longitude: long)
	}
}

// Area is a primitive used to model linear elements (start/end locations) on the course.
public struct Area: Codable, Hashable {
	public static func == (lhs: Area, rhs: Area) -> Bool {
		lhs.start.latitude == rhs.start.latitude && lhs.start.longitude == rhs.start.longitude
		&& lhs.end.latitude == rhs.end.latitude && lhs.end.longitude == rhs.end.longitude
	}
	
	public let start: LocationCoordinate2D
	public let end: LocationCoordinate2D
	public var center: LocationCoordinate2D { .init(latitude: 0.5*(start.latitude + end.latitude), longitude: 0.5*(start.longitude + end.longitude)) }
	
	// green specific (flag positions, as opposed to green boundaries)
	public var centerFlag: LocationCoordinate2D { .interpolate(start, end, t: 0.5) }
	public var frontFlag: LocationCoordinate2D { .interpolate(start, end, t: 1.0/6.0) }
	public var backFlag: LocationCoordinate2D { .interpolate(start, end, t: 5.0/6.0) }
	
	public var frame: LocationFrame { .init(start, end) }
	
	enum CodingKeys: CodingKey {
		case startLatitude, startLongitude, endLatitude, endLongitude
	}

	public init(start: LocationCoordinate2D, end: LocationCoordinate2D) {
		self.start = start
		self.end = end
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let startLatitude = try container.decode(Double.self, forKey: .startLatitude)
		let startLongitude = try container.decode(Double.self, forKey: .startLongitude)
		let endLatitude = try container.decode(Double.self, forKey: .endLatitude)
		let endLongitude = try container.decode(Double.self, forKey: .endLongitude)
		
		start = LocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
		end = LocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(start.latitude, forKey: .startLatitude)
		try container.encode(start.longitude, forKey: .startLongitude)
		try container.encode(end.latitude, forKey: .endLatitude)
		try container.encode(end.longitude, forKey: .endLongitude)
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(start.latitude)
		hasher.combine(start.longitude)
		hasher.combine(end.latitude)
		hasher.combine(end.longitude)
	}
}
