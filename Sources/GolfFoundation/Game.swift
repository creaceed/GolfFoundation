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

// A played ball stroke
public struct Stroke: Identifiable, Hashable, Codable {
	public let id: UUID
	public let date: Date
	public let rawLocation: LocationCoordinate2D? // when the + button was tapped
	public var location: LocationCoordinate2D? // revised after shot matching
	
	private enum CodingKeys: String, CodingKey {
		case id
		case date
		case location
		case rawLocation
	}
	
	public init(date: Date, rawLocation: LocationCoordinate2D?, location: LocationCoordinate2D?) {
		self.id = UUID()
		self.date = date
		self.location = location
		self.rawLocation = rawLocation
	}
}

// zero-based hole index in the played course (GolfMap + section combo).
// In UI, shows up as holeId+1 ("Hole 1" has holeId==0)
public typealias HoleID = Int

// Record of a player per-hole strokes and stats.
public struct PlayerRecord: Hashable, Codable {
	public struct HoleStats: Hashable, Codable {
		public var gir: Bool // green in regulation
		public var fairway: Bool
		public var putts: Int
		
		public init(gir: Bool, fairway: Bool, putts: Int) {
			self.gir = gir
			self.fairway = fairway
			self.putts = putts
		}
	}
	
	public struct HoleScore: Hashable, Codable {
		public var strokes: [Stroke]
		public var abandoned: Bool = false
		public var stats: HoleStats? = nil
		
		public mutating func updateStrokes(updater: (inout Stroke) -> Void) {
			for i in strokes.indices {
				updater(&strokes[i])
			}
		}
		
		public init(strokes: [Stroke]) {
			self.strokes = strokes
		}
		
		public init(from decoder: Decoder) throws {
			let container: KeyedDecodingContainer<PlayerRecord.HoleScore.CodingKeys> = try decoder.container(keyedBy: PlayerRecord.HoleScore.CodingKeys.self)
			self.strokes = try container.decode([Stroke].self, forKey: PlayerRecord.HoleScore.CodingKeys.strokes)
			self.abandoned = try container.decode(Bool.self, forKey: PlayerRecord.HoleScore.CodingKeys.abandoned)
			self.stats = try? container.decodeIfPresent(PlayerRecord.HoleStats.self, forKey: PlayerRecord.HoleScore.CodingKeys.stats)
		}
	}
	
	public var holes: [ HoleID :  HoleScore ]
	
	// complete means strokes for each hole (abandonned OK)
	public func scoreComplete(holeCount: Int) -> Bool {
		return holes.values.filter({ $0.strokes.count >= 1 || $0.abandoned }).count == holeCount
	}
	// complete means stats avail for each hole
	public func statsComplete(holeCount: Int) -> Bool {
		return holes.values.compactMap { $0.stats }.count == holeCount
	}
	
	public func strokes(hole: HoleID) -> [Stroke]? {
		return holes[hole]?.strokes
	}
	
	public func strokeCount(hole: HoleID) -> Int {
		return strokes(hole: hole)?.count ?? 0
	}
	
	public func stats(hole: HoleID) -> HoleStats? {
		return holes[hole]?.stats
	}
	
	// now: always returns a number. Counts 9 for abandonned holes.
	// previously: will return nil if there are abandonned holes.
	public func totalStrokeCount() -> Int {
		//return holes.values.reduce(0) { if $0 == nil || $1.abandoned { return nil} else { return $0! + $1.strokes.count } }
		return holes.values.reduce(0) { return $0 + ($1.abandoned ? 9 :  $1.strokes.count) }
	}
	
	/*func statisticsValid() -> Bool {
		holes.count > 0 && holes.values.reduce(true) { $0 && ($1.stats != nil) }
	}*/
	
	public mutating func updateStrokes(updater: (inout Stroke) -> Void) {
		for hid in holes.keys {
			holes[hid]?.updateStrokes(updater: updater)
		}
	}
}

public enum HoleStatus {
	case active(count: Int)
	case abandoned
}

public enum ScorecardHoleAnnotation {
	case eagle // PAR - 2
	case birdie // PAR - 1
	case bogey // PAR + 1
	case doubleBogey // PAR + 2
	case overDoubleBogey // PAR > 2
}

public struct Game: Identifiable, Hashable, Codable {
	public let id: UUID
	
	public var courseSummary: Course.Summary
	
	public let startDate: Date
	public var endDate: Date
	public var duration: TimeInterval = 0 // pauses duration subtracted
	
	public let playerGroup: PlayerGroup // previously: group
	public var records: [Player.ID : PlayerRecord] = [:]
	
	public var associatedWorkoutUUID: UUID? // HealthKit data

	public static var empty: Game {
		return Game(group: PlayerGroup(players: [], creationDate: Date()), courseSummary: Course.Summary(length: 9), startDate: Date())
	}
	
	public init(group: PlayerGroup, courseSummary: Course.Summary, startDate: Date) {
		self.id = UUID()
		self.playerGroup = group
		self.startDate = startDate
		self.endDate = startDate
		self.courseSummary = courseSummary
	}
	
	public func scorecardAnnotation(hole: HoleID, playerID: Player.ID) -> ScorecardHoleAnnotation? {
		var symbol: ScorecardHoleAnnotation? = nil
		
		if let holeSummaries = courseSummary.holeSummaries {
			let summary = holeSummaries[hole]
			let status = holeStatus(hole: hole, playerID: playerID)
			
			switch status {
				case .active(let count) where count == summary.par.parNumber-2:
					symbol = .eagle
				case .active(let count) where count == summary.par.parNumber-1:
					symbol = .birdie
				case .active(let count) where count == summary.par.parNumber+1:
					symbol = .bogey
				case .active(let count) where count == summary.par.parNumber+2:
					symbol = .doubleBogey
				case .active(let count) where count > summary.par.parNumber+2:
					symbol = .overDoubleBogey
				default:
					symbol = nil
			}
		}
		
		return symbol
	}
	
	public func holeStatus(hole: HoleID, playerID: Player.ID) -> HoleStatus {
		var status: HoleStatus = .active(count: 0)
		
		if let hole = records[playerID]?.holes[hole] {
			if hole.abandoned {
				status = .abandoned
			} else {
				status = .active(count: hole.strokes.count)
			}
		}
		
		return status
	}
	
	public func record(for playerID: Player.ID) -> PlayerRecord {
		return records[playerID] ?? PlayerRecord(holes: [:])
	}
	public mutating func updatePlayerRecord(playerID: Player.ID, updater: (inout PlayerRecord) -> Void) {
		var record: PlayerRecord = records[playerID] ?? PlayerRecord(holes: [:])
		updater(&record)
		records[playerID] = record
	}
	public func holeStatistics(hole: HoleID, playerID: Player.ID = Player.ownerID) -> PlayerRecord.HoleStats? {
		return records[playerID]?.holes[hole]?.stats
	}
	public func statsComplete(for playerId: Player.ID) -> Bool {
		let holeCount = courseSummary.length
		guard let record = records[playerId] else { return false }
		return record.statsComplete(holeCount: holeCount)
	}
	public func scoreComplete(for playerId: Player.ID) -> Bool {
		let holeCount = courseSummary.length
		guard let record = records[playerId] else { return false }
		return record.scoreComplete(holeCount: holeCount)
	}
	
	/*func statisticsValidForPlayer(_ playerId: Player.ID) -> Bool {
		guard let record = records[playerId] else { return false }
		return record.statisticsValid()
	}*/
	
	public func strokes(hole: HoleID, playerID: Player.ID) -> [Stroke]? {
		return records[playerID]?.strokes(hole: hole)
	}
	public func strokeCount(hole: HoleID, playerID: Player.ID) -> Int {
		return records[playerID]?.strokeCount(hole: hole) ?? 0
	}
	public func totalStrokeCount(playerID: Player.ID) -> Int {
		var count: Int = 0
		
		for hole in 0..<courseSummary.length {
			count = count + strokeCount(hole: hole, playerID: playerID)
		}
		
		return count
	}
	@discardableResult
	public mutating func appendStroke(hole: HoleID, playerID: Player.ID, date: Date = .now, location: LocationCoordinate2D?, rawLocation: LocationCoordinate2D?) -> Stroke.ID {
		var strokeId: Stroke.ID!
		updateHole(hole: hole, playerID: playerID) { hole in
			let stroke = Stroke(date: date, rawLocation: rawLocation, location: location)
			strokeId = stroke.id
			hole.strokes.append(stroke)
		}
		return strokeId
	}
	public func lastStroke(hole: HoleID, player: Player.ID) -> Stroke? {
		return records[player]?.holes[hole]?.strokes.last
	}
	public func canRemoveStroke(hole: HoleID, playerID: Player.ID) -> Bool {
		var flag = records[playerID]?.holes[hole]?.strokes.count ?? 0 > 0
		
		if let hole = records[playerID]?.holes[hole], hole.abandoned {
			flag = true
		}
		
		return flag
	}
	public func canAppendStroke(hole: HoleID, playerID: Player.ID) -> Bool {
		var flag = true
		if let hole = records[playerID]?.holes[hole], hole.abandoned { flag = false }
		return flag
	}
	public mutating func removeLastStroke(hole: HoleID, playerID: Player.ID) {
		records[playerID]?.holes[hole]?.strokes.removeLast()
	}
	public mutating func removeAllStrokes(hole: HoleID, playerID: Player.ID) {
		records[playerID]?.holes[hole]?.strokes.removeAll()
	}
	public mutating func updateHoleAbandonedState(_ abandoned: Bool, hole: HoleID, playerID: Player.ID) {
		updateHole(hole: hole, playerID: playerID) { $0.abandoned = abandoned }
	}
	public mutating func updateHoleStatistics(_ statistics: PlayerRecord.HoleStats, hole: HoleID, playerID: Player.ID = Player.ownerID) {
		updateHole(hole: hole, playerID: playerID) { $0.stats = statistics }
	}
	private mutating func updateHole(hole hid: HoleID, playerID: Player.ID, updater: (inout PlayerRecord.HoleScore) -> Void) {
		updatePlayerRecord(playerID: playerID) { record in
			var hole = record.holes[hid] ?? PlayerRecord.HoleScore(strokes: [])
			updater(&hole)
			record.holes[hid] = hole
		}
	}
	
	
	
	
	// Codable
	public enum CodingKeys: CodingKey {
		case id, courseSummary, startDate, endDate, duration, playerGroup, group /* old key */, records, associatedWorkoutUUID
	}
	public init(from decoder: Decoder) throws {
		// mostly code to handle old files + migrate to new format
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		id = try container.decode(UUID.self, forKey: .id)
		
		courseSummary = try container.decode(Course.Summary.self, forKey: .courseSummary)
		
		startDate = try container.decode(Date.self, forKey: .startDate)
		// using some fallback if missing (older format)
		endDate = (try? container.decode(Date.self, forKey: .endDate)) ?? startDate
		duration = (try? container.decode(TimeInterval.self, forKey: .duration)) ?? (endDate.timeIntervalSince(startDate))
		
		
		var playerGroup: PlayerGroup?
		
		playerGroup = try? container.decode(PlayerGroup.self, forKey: .playerGroup)
		playerGroup = playerGroup ?? (try? container.decode(PlayerGroup.self, forKey: .group)) // decoding older format if newer not found
		if let playerGroup {
			self.playerGroup = playerGroup
		} else {
			throw DecodingError.keyNotFound(CodingKeys.playerGroup, .init(codingPath: decoder.codingPath + [CodingKeys.playerGroup], debugDescription: "key not found"))
		}
		
		records = try container.decode(type(of: records), forKey: .records)
		
		associatedWorkoutUUID = try container.decode(type(of: associatedWorkoutUUID), forKey: .associatedWorkoutUUID)
	}
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		// Use the new key for encoding
		try container.encode(id, forKey: .id)
		try container.encode(courseSummary, forKey: .courseSummary)
		try container.encode(startDate, forKey: .startDate)
		try container.encode(endDate, forKey: .endDate)
		try container.encode(duration, forKey: .duration)
		try container.encode(playerGroup, forKey: .playerGroup)
		try container.encode(records, forKey: .records)
		try container.encode(associatedWorkoutUUID, forKey: .associatedWorkoutUUID)
	}
}
