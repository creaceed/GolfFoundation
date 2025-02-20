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

// Course length is typically derived from GolfMap + selected [HoleGroupSection]
// When course data is not available, GenericCourseLength is used to specify played length.
public enum GenericCourseLength: Int, Codable, CaseIterable, Identifiable, Hashable {
	case length6 = 6
	case length9 = 9
	case length12 = 12
	case length18 = 18
	case length27 = 27
	case length36 = 36
	// could add a custom(length:) one
	
	public var holeCount: Int {
		return rawValue
	}
	
	public var id: RawValue { rawValue }
	
	private enum CodingKeys: String, CodingKey {
		case rawValue
	}
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let rawValue = try container.decode(Int.self)
		
		switch rawValue {
				// older values (migration)
			case 0: self = .length9
			case 1: self = .length18
			case 2: self = .length27
			case 3: self = .length36
				
				// modern values
			case 6: self = .length6
			case 9: self = .length9
			case 12: self = .length12
			case 18: self = .length18
			case 27: self = .length27
			case 36: self = .length36
				
				// Add cases to map old values to new values
			default:
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid CourseLength value: \(rawValue)")
		}
	}
}

// Par (for each hole)
public enum Par: Int, Codable, CaseIterable {
	//case two = 2 // doesn't exist
	case par3 = 3
	case par4 = 4
	case par5 = 5
	case par6 = 6 // rare but exists.
	
	public var parNumber: Int { return self.rawValue }
}

// Hazard representation (linear segment)
public struct Hazard: Identifiable, Hashable, Codable {
	public enum Kind: String, Hashable, Codable, CaseIterable {
		case bunker, water, other
	}
	public let id: UUID
	public var kind: Kind
	public let start: LocationCoordinate2D
	public let end: LocationCoordinate2D
	public var center: LocationCoordinate2D { .interpolate(start, end, t: 0.5) }
	
	public init(id: UUID = UUID(), kind: Kind = .bunker, start: LocationCoordinate2D, end: LocationCoordinate2D) {
		self.id = id
		self.kind = kind
		self.start = start
		self.end = end
	}
}

// Facilities of golf clubs
public struct Facility: Identifiable, Hashable, Codable {
	public enum Kind: String, Hashable, Codable, CaseIterable {
		case chipping, putting, driving, clubhouse, parking
	}
	
	public let id: UUID
	public var kind: Kind
	public var location: LocationCoordinate2D
	
	public init(id: UUID = UUID(), kind: Kind = .chipping, location: LocationCoordinate2D) {
		self.id = id
		self.kind = kind
		self.location = location
	}
}

// Variant defined to override defaults of a golf course. Like personal aiming target (tee shot) or winter green.
// Variants can be set while playing, and even be combined together, following the precedence rule defined below.
public enum Variant: String, Hashable, Codable, CaseIterable, Identifiable, CodingKey {
	public typealias Name = String
	public typealias PrecedenceOp = (Variant, Variant) -> Bool
	
	case seasonal, personal, temporary
	public var id: String { return rawValue }
	
	public static func defaultPrecedence(a: Variant, b: Variant) -> Bool {
		let vs = Variant.allCases
		if let ai = vs.firstIndex(of: a), let bi = vs.firstIndex(of: b) {
			return ai < bi
		} else {
			fatalError()
		}
	}
	
	public struct Selector {
		public let orderedVariants: [Variant]
		
		public init(variants: Set<Variant> = [], precedence: @escaping PrecedenceOp = Variant.defaultPrecedence(a:b:)) {
			self.orderedVariants = variants.sorted(by: precedence)
		}
	}
	
	public struct Override: Hashable, Codable {
		public var tee: Area?
		public var green: Area?
		public var checkpoint: LocationCoordinate2D?
		
		public func channelIsSet(_ channel: Channel) -> Bool {
			switch channel {
				case .tee: return tee != nil
				case .green: return green != nil
				case .checkpoint: return checkpoint != nil
			}
		}
		
		public init(tee: Area? = nil, green: Area? = nil, checkpoint: LocationCoordinate2D? = nil) {
			self.tee = tee
			self.green = green
			self.checkpoint = checkpoint
		}
		
		public var isEmpty: Bool {
			return tee == nil && green == nil && checkpoint == nil
		}
	}
	public enum Channel {
		case tee, green, checkpoint
	}
}


// if we want to make 2 versions of the hole: mutable (for editor app) / immutable (for runtime app).
/*
 protocol HoleProtocol: Identifiable, Hashable, Codable {
	 var id: UUID { get }
	 
	 var par: Par { get }
	 var tee: Area? { get }
	 var green: Area? { get }
	 
	 init(par: Par, tee: Area?, green: Area?)
 }
 */


// Hole representation in a golf map (as opposed to hole score) representation
public struct Hole: Identifiable, Hashable, Codable {
	public let id: UUID
	public var par: Par
	public var tee: Area?
	public var green: Area?
	public var checkpoint: LocationCoordinate2D?
	public var hazards: [Hazard] = []
	public var variants: [Variant : Variant.Override] = [:]
	
	public var frame: LocationFrame? {
		// ignore variants for now. frame() method with options might be a better way of handling them.
		LocationFrame.expanding(LocationFrame.union(tee?.frame, green?.frame), checkpoint)
	}
	
	public mutating func writingVariant(_ variant: Variant, _ block: (inout Variant.Override)->Void) {
		block(&variants[variant, default: .init()])
	}
	public mutating func createVariantIfAbsent(_ variant: Variant) -> Void {
		if variants[variant] == nil {
			variants[variant] = .init()
		}
	}
	public mutating func updatingHazard(_ index: Int, _ block: (inout Hazard)->Void) {
		block(&hazards[index])
	}
	
	// nil if no passed variant matches
	public func resolvedVariantFor(selector: Variant.Selector, channel: Variant.Channel) -> Variant? {
		for variant in selector.orderedVariants {
			if variants[variant]?.channelIsSet(channel) == true {
				return variant
			}
		}
		return nil
	}
	
	// accessors that handle variants/fallback if not avail.
	public func tee(selector: Variant.Selector = .init()) -> Area? {
		for variant in selector.orderedVariants {
			if let tee = variants[variant]?.tee { return tee }
		}
		return tee
	}
	public func green(selector: Variant.Selector = .init()) -> Area? {
		for variant in selector.orderedVariants {
			if let green = variants[variant]?.green { return green }
		}
		return green
	}
	public func checkpoint(selector: Variant.Selector = .init()) -> LocationCoordinate2D? {
		for variant in selector.orderedVariants {
			if let checkpoint = variants[variant]?.checkpoint { return checkpoint }
		}
		return checkpoint
	}
	
	public init(par: Par = .par3) {
		self.id = UUID()
		self.par = par
	}
	
	
	// Custom: we need to handle it ourselves, for when the struct changes
	enum CodingKeys: CodingKey {
		case id, par, tee, start /* old */, startArea /* old */, green, greenArea /* old */, checkpoint, hazards, variants
	}
	public init(from decoder: Decoder) throws {
		// code to handle older file types + migrate to new format
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		self.id = try container.decode(UUID.self, forKey: .id)
		self.par = try container.decode(Par.self, forKey: .par)
		
		var tee = try? container.decode(Area.self, forKey: .tee)
		tee = tee ?? (try? container.decode(Area.self, forKey: .start))
		tee = tee ?? (try? container.decode(Area.self, forKey: .startArea))
		if let tee {
			self.tee = tee
		}
		if let green = (try? container.decode(Area.self, forKey: .green))
			?? (try? container.decode(Area.self, forKey: .greenArea)) {
			self.green = green
		}
		self.checkpoint = try? container.decode(LocationCoordinate2D?.self, forKey: .checkpoint)
		self.hazards = (try? container.decode([Hazard].self, forKey: .hazards)) ?? []
		//self.variants = (try? container.decode([Variant:Variant.Override].self, forKey: .variants)) ?? [:]
		
		var variantsDictionary = [Variant: Variant.Override]()
		let variantsContainer = try? container.nestedUnkeyedContainer(forKey: .variants)
		
		if variantsContainer != nil {
			// removing optional (but still need to mutate)
			var variantsContainer = variantsContainer!
			while !variantsContainer.isAtEnd {
				// skipping bad keys. We could handle it differently if we allow custom variants in the future
				if let key = try? variantsContainer.decode(Variant.self) {
					if !variantsContainer.isAtEnd {
						let value = try variantsContainer.decode(Variant.Override.self)
						variantsDictionary[key] = value
					}
				} else {
					continue
				}
			}
		}
		
		variants = variantsDictionary
	}
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		// Use the new key for encoding
		try container.encode(id, forKey: .id)
		try container.encode(par, forKey: .par)
		try container.encode(tee, forKey: .start)
		try container.encode(green, forKey: .green)
		try container.encode(checkpoint, forKey: .checkpoint)
		try container.encode(hazards, forKey: .hazards)
		
		/*let s_variants: [String : Variant.Override] = variants.map { v, o in
			(v.rawValue, o)
		}
		try container.encode(s_variants, forKey: .variants)*/
		
		//var nestedContainer = container.nestedContainer(keyedBy: Variant.self, forKey: .variants)
		
		// JSON Encoder does not honor .sortedKey ordering when the key in an enum (even a string one)
		// this code will produce the same output as default encoder, but with sorted keys (ie, stable json for git)
		var nestedContainer = container.nestedUnkeyedContainer(forKey: .variants)
		let sortedKeys = variants.keys.sorted { $0.rawValue < $1.rawValue }
		for key in sortedKeys {
			if let value = variants[key] {
				try nestedContainer.encode(key)
				try nestedContainer.encode(value)
			}
		}
	}
}
// HoleGroup is used to organize holes to match course structure.
// Note that 18H courses that can be played as 9H don't need 2 9H groups anymore, as
// an 18H group can be split in 2 at runtime (that is, if indivisible is false) and recombined
// using HoleGroupSection below to form the actually played course.
public struct HoleGroup: Identifiable/*, ObservableObject*/, Codable, Hashable {
	public let id: UUID
	public var name: String
	public var holes: [Hole]
	public var practice: Bool // training-only hole group (won't be combined)
	public var indivisible: Bool // an indivisible 18H group won't allow combos of its 9H parts
	
	public var startCoordinate: LocationCoordinate2D? { holes.first?.tee?.center }

	public var frame: LocationFrame? {
		let frame: LocationFrame? = holes.reduce(nil) { LocationFrame.union($0, $1.frame) }
		return frame
	}
	
	public init(id: UUID = .init(), name: String, holes: [Hole], practice: Bool = false, indivisible: Bool = false) {
		self.id = id
		self.name = name
		self.holes = holes
		self.practice = practice
		self.indivisible = indivisible
	}

	// Custom: we need to handle it ourselves, for when the struct changes
	enum CodingKeys: CodingKey {
		case id, name, holes, practice, indivisible
	}
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		self.id = try container.decode(UUID.self, forKey: .id)
		self.name = try container.decode(String.self, forKey: .name)
		self.holes = try container.decode([Hole].self, forKey: .holes)
		self.practice = (try? container.decode(Bool.self, forKey: .practice)) ?? false
		self.indivisible = (try? container.decode(Bool.self, forKey: .indivisible)) ?? false
	}
	public func encode(to encoder: Encoder) throws {
		do {
			var container = encoder.container(keyedBy: CodingKeys.self)
			
			try container.encode(id, forKey: .id)
			try container.encode(name, forKey: .name)
			try container.encode(holes, forKey: .holes)
			try container.encode(practice, forKey: .practice)
			try container.encode(indivisible, forKey: .indivisible)
		} catch {
			//logError("error while decoding HoleGroup: \(error)")
			throw error
		}
	}
}

// A hole group section is defined relatively to a hole group. For instance, if a hole group is 18H,
// .front9 and back9 section can be derived from it. Sections of possibly different groups are combined
// together at runtime to define the played course.
public struct HoleGroupSection: Hashable, Codable {
	public enum SectionType: Int, Codable {
		case all = 0 // valid for any group
		case front9 = 1, back9 = 2 // valid for 18 holes groups
	}
	
	public let groupIndex: Int // index in golfMap.groups
	public let holeCount: Int
	public let type: SectionType
	
	public init(groupIndex: Int, holeCount: Int, type: SectionType) {
		self.groupIndex = groupIndex
		self.holeCount = holeCount
		self.type = type
	}
	
	func resolveHoles(from groups: [HoleGroup]) -> [Hole] {
		let group = groups[groupIndex]
		switch type {
			case .all:
				return group.holes
			case .front9:
				return Array(group.holes.prefix(9))
			case .back9:
				return Array(group.holes.suffix(9))
		}
	}
	static func resolveHoles(sections: [HoleGroupSection], from groups: [HoleGroup]) -> [Hole] {
		return sections.flatMap { $0.resolveHoles(from: groups) }
	}
}

// Modeling of a golf map with its venue / facilities and hole groups.
public struct GolfMap: Identifiable, Codable, Hashable {
	public typealias CountryCode = String
	
	public struct Address: Hashable, Codable {
		public var street: String?
		public var subLocality: String?
		public var city: String?
		public var subAdministrativeArea: String?
		public var state: String?
		public var postalCode: String?
		public var countryCode: CountryCode
	}
	
	// Not yet implemented.
	// Level is describes the level of details contained in the modeling. Ie:
	// - Level 2 provides start area / green area / (optional) checkpoints for every hole.
	/*public enum MapLevel: Int, Codable {
		case standard = 2
	}*/
	public private(set) var id: UUID
	public var name: String?
	public var shortName: String?
	public var address: Address
	
	//var level: MapLevel = .standard
	public var groups: [HoleGroup] { // now includes practice groups (participate in same mechanics for hole detection)
		didSet {
			cleanupAffinitiesIfNeeded()
		}
	}
	// mostly for previews (won't split 18H groups in 9H)
	public var wholeSections: [HoleGroupSection] {
		groups.enumerated().map { HoleGroupSection(groupIndex: $0.0, holeCount: $0.1.holes.count, type: .all) }
	}
	
	// allowed sections (taking into account .indivisible flag)
	public var sections: [HoleGroupSection] {
		groups.enumerated().flatMap { gi, group in
			var sections: [HoleGroupSection] = [HoleGroupSection(groupIndex: gi, holeCount: group.holes.count, type: .all)]

			if !group.indivisible && group.holes.count == 18 {
				sections += [
					HoleGroupSection(groupIndex: gi, holeCount: 9, type: .front9),
					HoleGroupSection(groupIndex: gi, holeCount: 9, type: .back9),
				]
			}
			
			return sections
		}
	}
	
	public var groupsForAffinities: [HoleGroup] {
		let compatibleGroups = groups.filter({ $0.practice == false })
		return compatibleGroups.count >= 2 ? compatibleGroups : []
	}
	
	public var facilities: [Facility] = []

	public var frame: LocationFrame? {
		let frame: LocationFrame? = groups.reduce(nil) { LocationFrame.union($0, $1.frame) }
		return frame
	}
	
	public static let currentVersion: Int = 1
	
	// Computed
	// could be set in model in the future (could well be clubhouse coordinate / unrelated to hole starts)
	public var coordinate: LocationCoordinate2D? { groups.first?.startCoordinate }
	public var allHoles: [Hole] { return groups.flatMap { $0.holes } }
	public var allNonPracticeHoles: [Hole] { return groups.filter { !$0.practice }.flatMap { $0.holes } }
	
	// Affinities define compatibility of hole groups, in which case they can be combined together (actually played course).
	// This makes it possible to combine the front 9 of a group with the front or back 9 of another (only if affinities allow that)
	// It should match the possibilities of the golf course.
	public var affinitiesEnabled: Bool = false
	public var affinities: [Set<HoleGroup.ID>] = []
	
	public init(id: UUID = .init(), name: String? = nil, shortName: String? = nil, countryCode: CountryCode = "us", /*level: MapLevel = .standard, */groups: [HoleGroup], practiceGroups: [HoleGroup] = []) {
		self.id = id
		self.name = name
		self.shortName = shortName
		//self.level = level
		self.groups = groups
		self.address = Address(countryCode: countryCode.lowercased())
	}
	
	public func holeGroup(_ id: HoleGroup.ID) -> HoleGroup? {
		return groups.first(where: { $0.id == id })
	}
	
	public var overridingId: GolfMap {
		var copy = self
		copy.id = UUID()
		return copy
	}
	
	// Custom: we need to handle it ourselves, for when the struct changes
	public enum CodingKeys: CodingKey {
		case version, id, groups, practiceGroups, name, shortName, address, /*level, */affinitiesEnabled, affinities, facilities
	}
	
	public init(from decoder: Decoder) throws {
		do {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			let version = (try? container.decode(Int.self, forKey: .version)) ?? 0
			if version > GolfMap.currentVersion {
				throw DecodingError.dataCorruptedError(
					forKey: .version,
					in: container,
					debugDescription: "Unsupported version"
				)
			}
			
			self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID() // upgrade if missing
			self.name = try container.decodeIfPresent(String.self, forKey: .name)
			self.shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
			self.address = (try? container.decode(Address.self, forKey: .address)) ?? Address(countryCode: "us")
			//self.level = try container.decode(MapLevel.self, forKey: .level)
			self.groups = try container.decode([HoleGroup].self, forKey: .groups)
			//self.practiceGroups = (try? container.decode([HoleGroup].self, forKey: .practiceGroups)) ?? []
			self.affinitiesEnabled = (try? container.decode(Bool.self, forKey: .affinitiesEnabled)) ?? false
			self.affinities = ((try? container.decode([[String]].self, forKey: .affinities)) ?? []).map({ Set($0.map({ UUID(uuidString: $0)! })) })
			self.facilities = (try? container.decode([Facility].self, forKey: .facilities)) ?? []
		} catch {
			//logError("error while decoding GolfMap: \(error)")
			throw error
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		try container.encode(GolfMap.currentVersion, forKey: .version)
		try container.encode(id, forKey: .id)
		try container.encodeIfPresent(name, forKey: .name)
		try container.encodeIfPresent(shortName, forKey: .shortName)
		try container.encode(address, forKey: .address)
		//try container.encode(level, forKey: .level)
		try container.encode(groups, forKey: .groups)
		try container.encode(affinitiesEnabled, forKey: .affinitiesEnabled)
		try container.encode(affinities.map({ set in
			// We transform the "set of strings" to an "ordered array of strings" in order to maintain the order in the json between savings
			let array = set.sorted { lhs, rhs in
				return lhs.uuidString.compare(rhs.uuidString) == .orderedAscending
			}
			return array
		}), forKey: .affinities)
		try container.encode(facilities, forKey: .facilities)
	}
	
	private mutating func cleanupAffinitiesIfNeeded() { // This function should be called when `groups` is changed
		// Tasks performed:
		// - Remove orphelin group ids from affinities
		// - Remove groups that are practice
		// - Remove affinities if they contain less than 2 groups
		
		let fromAffinitiesEnabled = affinitiesEnabled
		let fromAffinities = affinities
		
		let existingGroupIds = groupsForAffinities.map({ $0.id })
		
		let toAffinities = fromAffinities.compactMap { fromGroupIds in
			let toGroupIds = fromGroupIds.filter({ existingGroupIds.contains($0) })
			if toGroupIds.count >= 2 {
				return toGroupIds
			} else {
				return nil
			}
		}
		
		if toAffinities != fromAffinities {
			affinities = toAffinities
		}
		
		// Reset enabled if we have less than 2 groups
		let toAffinitiesEnabled = fromAffinitiesEnabled && existingGroupIds.count >= 2
		
		if toAffinitiesEnabled != fromAffinitiesEnabled {
			affinitiesEnabled = toAffinitiesEnabled
		}
	}
}

public typealias CourseLength = Int

// Course models the played course as selected by the player. It is built from the Golfmap + user choice (section combo).
// The course itself is not meant to be archived/reused after some time, just a temporary storage for app relaunch
// to implement recovery after a crash or a kill (same app version).
// Summaries are meant to be included into saved games for display purpose.
public struct Course: Codable {
	public struct Mapped: Codable {
		public let golfMap: GolfMap
		//public let holeGroups: [HoleGroup.ID]
		public let sections: [HoleGroupSection] // relative to the golfmap
		public let holes: [Hole]
	}
	
	// Played course summary are included in saved games for display purpose.
	public struct Summary: Codable, Hashable {
		public struct HoleSummary: Codable, Hashable {
			public let id: Hole.ID
			public let par: Par
			
			public init(id: Hole.ID, par: Par) {
				self.id = id
				self.par = par
			}
		}
		public struct HoleGroupSummary: Codable, Hashable {
			public let id: HoleGroup.ID
			public let name: String
			public let holeCount: Int
			public let sectionType: HoleGroupSection.SectionType
			
			public init(id: HoleGroup.ID, name: String, holeCount: Int, sectionType: HoleGroupSection.SectionType) {
				self.id = id
				self.name = name
				self.holeCount = holeCount
				self.sectionType = sectionType
			}
			
			public init(from decoder: Decoder) throws {
				let container = try decoder.container(keyedBy: CodingKeys.self)
				self.id = try container.decode(HoleGroup.ID.self, forKey: .id)
				self.name = try container.decode(String.self, forKey: .name)
				self.holeCount = try container.decode(Int.self, forKey: .holeCount)
				// previous versions may not contain this key -> .all is what we want here.
				self.sectionType = try container.decodeIfPresent(HoleGroupSection.SectionType.self, forKey: .sectionType) ?? .all
			}
		}
		public struct GolfMapSummary: Codable, Hashable {
			public let id: GolfMap.ID
			public let name: String?
			public let shortName: String?
			
			public init(id: GolfMap.ID, name: String?, shortName: String?) {
				self.id = id
				self.name = name
				self.shortName = shortName
			}
			
			public init(from decoder: Decoder) throws {
				let container = try decoder.container(keyedBy: CodingKeys.self)
				self.id = try container.decode(GolfMap.ID.self, forKey: .id)
				self.name = try container.decodeIfPresent(String.self, forKey: .name)
				self.shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
			}
		}
		
		public let golfmap: GolfMapSummary?
		public let holeGroups: [HoleGroupSummary]?
		public let holeSummaries: [HoleSummary]?
		public let totalPar: Int?
		public let length: Int
		
		public init(golfMap: GolfMapSummary, holeGroups: [HoleGroupSummary], holeSummaries: [HoleSummary], totalPar: Int) {
			self.golfmap = golfMap
			self.holeGroups = holeGroups
			self.holeSummaries = holeSummaries
			//self.length = holeGroups.reduce(0, { $0 + $1.holeCount })
			self.length = holeSummaries.count
			self.totalPar = totalPar
		}
		
		public init(length: Int) {
			self.length = length
			self.golfmap = nil
			self.holeGroups = nil
			self.holeSummaries = nil
			self.totalPar = nil
		}
	}
	
	public let length: CourseLength
	public var summary: Summary {
		if let mapped {
			let golfMapSummary = Summary.GolfMapSummary(id: mapped.golfMap.id,
														name: mapped.golfMap.name,
														shortName: mapped.golfMap.shortName)
			let holeGroupSummaries = mapped.sections.map { section in
				let group = mapped.golfMap.groups[section.groupIndex]
				return Summary.HoleGroupSummary(
					id: group.id,
					name: group.name,
					holeCount: section.holeCount,
					sectionType: section.type
				)
			}
			let holeSummaries = mapped.holes.map {
				Summary.HoleSummary(id: $0.id, par: $0.par)
			}
			
			let totalPar = mapped.holes.reduce(0) { $0 + $1.par.parNumber }
			
			return Summary(golfMap: golfMapSummary, holeGroups: holeGroupSummaries, holeSummaries: holeSummaries, totalPar: totalPar)
		} else {
			return Summary(length: length)
		}
	}
	// nil when map is not available (only course length is recorded)
	public let mapped: Mapped?

	// Course with just a hole length
	public init(length: CourseLength) {
		self.length = length
		self.mapped = nil
	}
	
	// Course with a full map specified
	public init(length: CourseLength, golfMap: GolfMap, sections: [HoleGroupSection]) {
		self.length = length
		var holes: [Hole] = []
		
		for section in sections {
			let group = golfMap.groups[section.groupIndex]
			
			switch section.type {
				case .all: holes.append(contentsOf: group.holes)
				case .front9: holes.append(contentsOf: group.holes.prefix(9))
				case .back9: holes.append(contentsOf: group.holes.suffix(9))
			}
		}
		self.mapped = Mapped(golfMap: golfMap, sections: sections, holes: holes)
	}
}
