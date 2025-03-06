//
//  RRDynamo+Codable.swift
//  RREngine
// 
//  Created on 10/12/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  A dynamo that can encode and decode its configuration.
@MainActor
public class RRDynamoCodable : RRDynamo, RRCodable {
	///  The portable type identifier, equal to `nil` for this non-portable base.
	nonisolated public class var typeId: String? { nil }
	nonisolated public var typeId: String? { Self.typeId }
	
	/*
	 *  Initialize the object.
	 */
	nonisolated internal override init(with config: any RRDynamoConfigurable, in environment: RREngineEnvironment, identifier: RRIdentifier? = nil) {
		super.init(with: config, in: environment, identifier: identifier)
		
		// - ensure that a brand new dynamo has its configuration snapshotted.
		self.snapshotConfiguration()
	}
	
	/// Initialize a dynamo from an encoded value.
	nonisolated public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let dynamoId  = try container.decode(RRIdentifier.self, forKey: .id)
		guard let iType = Self.self as? any RRDynamoInternal.Type,
			  let cType = iType.codableConfigurationType,
			  let env = decoder.userInfo[.RRCodableEngineEnvironment] as? RREngineEnvironment else {
			// - decoding dynamos requires an internal implementation, codable configuration and environment.
			throw RRError.assertionFailed
		}
		let config = try cType.init(from: decoder)
		super.init(with: config, in: env, identifier: dynamoId)
		
		// NOTE: Do not snapshot a decoded dynamo to avoid unnecessary writes.
	}
	
	// DESIGN: This work doesn't encode state because this is intended
	// 	 	   for document storage encoding.
	// DESIGN  The dynamo implements an alternative form of 'snapshot' encoding where
	//		   it will notify the environment when configuration is changed so
	// 	 	   that the dynamo data is in the next full-engine snapshot.  Because of this,
	// 		   this encoder is declared `final` in order to guarantee that
	// 	 	   sub-classes never add anything that isn't in the configuration structure.
	
	/// Encode a dynamo's content.
	nonisolated public final func encode(to encoder: Encoder) throws {
		//  !!!! NOTE:  This is mainly a _reference_ implementation since the snapshot (below) is
		// 	 			most often used for the document.  Make sure this has the same behavior as
		// 	 			the snapshot.
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.id, forKey: .id)
		guard let eConfig = self.__config as? any RRDynamoCodableConfigurable else {
			assert(false, "Codable dynamos require a suitable configuration.")
			throw RRError.assertionFailed
		}
		try eConfig.encode(to: encoder)
	}
	
	/*
	 *  The dynamo configuration has been updated.
	 */
	override nonisolated func configurationWasUpdated() {
		super.configurationWasUpdated()
		
		// - ensure the engine is always aware the latest modifications
		snapshotConfiguration()
	}
	
	fileprivate enum CodingKeys : String, CodingKey {
		case id = "dynamoId"
	}
}

typealias RRCRefDynamo = RRCRef<RRDynamoCodable>

/*
 *  Internal implementation.
 */
extension RRDynamoCodable {
	/*
	 *  When the dynamo configuration changes, this method will ensure the engine
	 *  retains a copy for the next time the engine configuration is saved.
	 */
	nonisolated private func snapshotConfiguration() {
		self.environment.saveDynamoSnapshot(self)
	}
}


// - Codable dynamos must include a codable configuration.
protocol RRDynamoCodableConfigurable : RRDynamoConfigurable, Codable {}

/*
 *  Convenience.
 */
extension CodingUserInfoKey {
	static var RRCodableEngineEnvironment: CodingUserInfoKey = .init(rawValue: "com.realproven.codable.engine.env")!
}

/*
 *  Convenience.
 */
extension JSONDecoder {
	/*
	 *  Return a suitable decoder for dynamo decoding and initialization.
	 */
	static func standardRRDynamoDecoder(using environment: RREngineEnvironment) -> JSONDecoder {
		let ret 								  = JSONDecoder.standardRRDecoder
		ret.userInfo[.RRCodableEngineEnvironment] = environment
		return ret
	}
}

/*
 *  A point-in time copy of a codable dynamo.
 *  DESIGN:  This is intended for use with an RRCRef wrapper to get consistent 
 *  DESIGN:  The objective is to be able to very quickly copy a dynamo without
 *  		 impacting its runnable behavior or introducing wasted encoding costs.
 * 			 Encoding occurs when it is only necessary to save and not before.
 *  DESIGN:  This is defined here so that it can share symbols with the codable dynamo and
 *  		 present a fairly opaque interface.
 */
typealias RRCRefDynamoSnapshot = RRCRef<RRDynamoCodableSnapshot>
final class RRDynamoCodableSnapshot : RRCodable {
	nonisolated var typeId: String? { dTypeId }
	
	let id: RRIdentifier
	private let dTypeId: String
	private let config: any RRDynamoCodableConfigurable
	
	/*
	 *  Initialize the snapshot.
	 */
	init(for dynamo: RRDynamoCodable) {
		self.id 	 = dynamo.id
		self.dTypeId = RRCodableRegistry.idForType(dynamo)
		self.config  = dynamo.__config as? (any RRDynamoCodableConfigurable) ?? InvalidConfiguration()
	}
	
	// - to provided an encodable config without a hard crash during init.
	private struct InvalidConfiguration : RRDynamoCodableConfigurable {}
	
	/*
	 *  Initialize the object.
	 */
	init(from decoder: Decoder) throws {
		// - these are intended to be encoded _only_ never decoded.
		throw RRError.assertionFailed
	}
	
	/*
	 *  Encode the snapshot.
	 *  DESIGN:  This needs to produce identical output to the RRDynamoCodable.encode()
	 */
	final func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: RRDynamoCodable.CodingKeys.self)
		try container.encode(self.id, forKey: .id)
		if let _ = config as? InvalidConfiguration {
			assert(false, "The dynamo source for a snapshot did not include a codable configuration.")
			throw RRError.assertionFailed
		}
		try config.encode(to: encoder)
	}
}
