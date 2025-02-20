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


public struct Player: Identifiable, Hashable, Codable {
	public var id: String
	public var name: String
	public var isOwner: Bool { id == Self.ownerID }
	
	// Device owner has a special ID.
	public static var ownerID: Player.ID { "owner" }
	
	public init(id: String = UUID().uuidString, name: String) {
		self.id = id
		self.name = name
	}
}

// Players playing the game together (reusable)
public struct PlayerGroup: Identifiable, Hashable, Codable {
	
	public let id: UUID
	public var players: [Player]
	public var isPersistent: Bool = false
	public let creationDate: Date
	
	public init(players: [Player], creationDate: Date) {
		self.id = UUID()
		self.players = players
		self.creationDate = creationDate
	}
		
	public var displayName: String { players.map({ $0.name }).joined(separator: ", ") }
}

extension PlayerGroup {
	public static func previewsPlayers(playersCount: Int = 4) -> PlayerGroup {
		let playerNames = ["Alain", "Raphael", "Jean-Christophe", "Frederic"]
		var players = playerNames[0..<playersCount].map({ Player(name: $0) })
		players[0].id = Player.ownerID
		return PlayerGroup(players: players,creationDate: Date())
	}
}

