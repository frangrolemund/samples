//
//  RREngine+Config.swift
//  RREngine
// 
//  Created on 10/16/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  DESIGN:  The configuration is an authoritative reference of the data
 *  		 that defines the behavior of the engine that is created when the engine
 *   		 is first initialized and later represents any changes to that
 *   		 behavior during the course of operation.
 *  DESIGN:  This should be considered a _cache_ of what was on disk +- any changes
 *           made to the current running engine behavior.
 *  DESIGN:  Runtime state of the engine is never saved in this structure because it
 *  		 is the basis for a document-based system for interacting with the engine.
 *  DESIGN:  The configuration deals primarily in NODEs as you can see below, which is
 *  		 intentional because a node is a special type of dynamo that naturally supports
 *  		 full encoding and naturally translates into the stateful runtime with complimentary
 * 			 references.
 */
struct RREngineConfig : RRIdentifiable {
	// - the repository identifier.
	let id: RRIdentifier
	var repositoryId: RRIdentifier { self.id }
	
	// - the complete list of nodes in the repository.
	private (set) var nodeIds: Set<RRIdentifier>
	
	// - the cached, encoded updates to node instances (complete list)
	private (set) var nodeSnapshots: [RRIdentifier : NodeSnapshot]
	
	/*
	 *  Initialize the object.
	 */
	init(id: RRIdentifier) {
		self.id 		   = id
		self.nodeIds	   = .init()
		self.nodeSnapshots = [:]
	}
}

/*
 *  Types
 */
extension RREngineConfig {
	// - the type of snapshot type is determined by how it was generated,
	//   allowing for deferred encoding when coming from the dynamos or
	//   retaining existing data when coming from the reloaded archives.
	enum NodeSnapshot {
		// ... the standard snapshot is the result of any changes and is designed for
		//     deferred encoding of the data to disk.
		case cref(RRCRefDynamoSnapshot, Date = .init())
		
		// ... the data snapshot is the result of loading an engine and is designed
		//     for efficient re-saving of the data.
		case data(Data, Date)
		
		func encode(with encoder: JSONEncoder) throws -> Data {
			switch self {
			case .cref(let snapshot, _):
				return try encoder.encode(snapshot)
				
			case .data(let data, _):
				return data
			}
		}
		
		var modifiedDate: Date {
			switch self {
			case .data(_, let modDt):
				return modDt
				
			case .cref(_, let createDt):
				return createDt
			}
		}
	}
}

/*
 * Accessors.
 */
extension RREngineConfig {
	/*
	 *  Cache a point-in-time copy of a node that should be saved with the next engine snapshot.
	 */
	mutating func saveNodeSnapshot(_ snapshot: RRDynamoCodableSnapshot) {
		self.nodeIds.insert(snapshot.id)
		self.nodeSnapshots[snapshot.id] = .cref(.init(snapshot))
	}
	
	/*
	 *  Cache a previously loaded point-in time copy of a node.
	 */
	mutating func saveNodeSnapshot(_ snapshot: Data, modifiedDate: Date?, forId dynamoId: RRIdentifier) {
		self.nodeIds.insert(dynamoId)
		self.nodeSnapshots[dynamoId] = .data(snapshot, modifiedDate ?? Date.distantPast)
	}
}
