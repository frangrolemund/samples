//
//  RRCodable.swift
//  RREngine
// 
//  Created on 10/15/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

///  An engine entity that supports full encoding/decoding.
public protocol RRCodable : Codable {
	/// The portable type identifier for the type or `nil` if intentionally not portable.
	nonisolated static var typeId: String? { get }
	
	/// The portable type identifier for the entity or `nil` if intentionally not portable.
	nonisolated var typeId: String? { get }
}
extension RRCodable {
	nonisolated static var typeId: String? { nil }
	nonisolated var typeId: String? { Self.typeId }
}

protocol RRClassCodable : AnyObject, RRCodable {}

/*
 *  General-purpose identification for class-based Codable entities.
 *  DESIGN: The rationale for this naming system is to facillitate a
 * 			an open file format that doesn't have implementation-specific
 * 			types named in it (ie class names).
 */
class RRCodableRegistry {
	/*
	 *  Explicit registration for codable types that can be encoded/decoded.
	 */
	nonisolated static func registerType(_ type: AnyObject.Type) {
		guard let cc = type as? RRCodable.Type, let typeId = cc.typeId else {
			return
		}
		
		_codableTypes.withLock {
			assert(_codableTypes.value[typeId] == nil || _codableTypes.value[typeId] == type, "Conflicting codable class type registration detected.")
			_codableTypes.value[typeId] = type as AnyClass
		}
	}
	
	/*
	 *  Find the codable type id for the provided type.
	 */
	nonisolated static func idForType(_ object: AnyObject) -> String {
		return (object as? RRCodable)?.typeId ?? idForType(type(of: object))
	}
	
	/*
	 *  Find the codable type id for the provided type.
	 */
	nonisolated static func idForType(_ type: AnyObject.Type) -> String {
		if let ct = type as? RRCodable.Type, let typeId = ct.typeId {
			return typeId
		}
		else {
			return NSStringFromClass(type)
		}
	}

	/*
	 *  Find the codable type for the provided type identifier.
	 */
	nonisolated static func typeForId(_ typeId: String) -> AnyClass? {
		_codableTypes.value[typeId] ?? NSClassFromString(typeId)
	}
	
	// ...it is VERY IMPORTANT that we save as AnyClass and not just RRDynamoCodable.Type
	//	  or the process of decoding won't understand the inheritance hierarchy at all.
	private static let _codableTypes: RRAtomic<[ String : AnyClass]> = .init([:])
}

/*
 *  A safely-encodable reference to a class instance.
 */
struct RRCRef<T: AnyObject> : Codable where T: Codable {
	let ref: T
	
	/*
	 *  Initialize the reference.
	 */
	init(_ ref: T) {
		self.ref = ref
	}
	
	/*
	 *  Decode the reference.
	 */
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let stdId 	  = try container.decode(String.self, forKey: .type)
		guard let tDef = RRCodableRegistry.typeForId(stdId) as? Codable.Type else {
			throw RRError.engineVersionMismatch(context: "The dynamo type '\(stdId)' is not supported by this engine.")
		}
		guard let dObj = try tDef.init(from: decoder) as? T else {
			// - this means the encoding describes an object of a type that this
			//   container no longer stores.
			assert(false, "Dynamo reference container type mismatch.")
			throw RRError.engineVersionMismatch(context: "The dynamo type '\(stdId)' is not supported in this context.")
		}
		self.ref = dObj
	}

	/*
	 *  Encode the dynamo.
	 */
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(RRCodableRegistry.idForType(ref), forKey: .type)
		try ref.encode(to: encoder)
	}
	
	private enum CodingKeys: String, CodingKey {
		case type 			= "typeId"
	}
}
