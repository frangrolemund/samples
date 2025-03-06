//
//  RRDynamoTests.swift
//  RREngineTests
//
//  Created on 10/13/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved.
//

import XCTest
@testable import RREngine

/*
 *  Verify dynamo behavior.
 */
@MainActor
final class RRDynamoTests: RREngineTestCase {
	/*
	 *  Test basic dynamo encoding.
	 */
	func testDynamoEncoding() throws {
		let env = RREngineEnvironment()
		
		let one = RRTestCDOne(with: env)
		one.config.oneText  = "ABCDEF"
		one.config.oneValue = 19
		let two = RRTestCDTwo(with: env)
		two.config.twoDate  = Date.distantFuture
		two.config.twoFloat = 3.14

		let list: [RRCRef<RRDynamoCodable>] = [.init(one), .init(two)]
		
		let je 	  	   = JSONEncoder.standardRREncoder
		let beforeData = try je.encode(list)
		self.log.info("\(String(data: beforeData, encoding: .utf8)!)")
		
		// - this should fail without the engine environment
		XCTAssertThrowsError(try JSONDecoder.standardRRDecoder.decode([RRCRef<RRDynamoCodable>].self, from: beforeData))
		
		// - rebuild with an environment
		let jd = JSONDecoder.standardRRDynamoDecoder(using: env)
		
		// ...still should fail without type registration if the typeId is non-nil
		XCTAssertThrowsError(try jd.decode([RRCRef<RRDynamoCodable>].self, from: beforeData))
		
		// - register types.
		RRCodableRegistry.registerType(RRTestCDOne.self)
		RRCodableRegistry.registerType(RRTestCDTwo.self)
		let listAfter = try jd.decode([RRCRef<RRDynamoCodable>].self, from: beforeData)
		
		XCTAssertEqual((listAfter[0].ref as? RRTestCDOne)?.config.oneText, "ABCDEF")
		XCTAssertEqual((listAfter[0].ref as? RRTestCDOne)?.config.oneValue, 19)
		
		XCTAssertTrue((listAfter[1].ref as? RRTestCDTwo)?.config.twoDate ?? Date.distantPast > Date())
		XCTAssertEqual((listAfter[1].ref as? RRTestCDTwo)?.config.twoFloat, 3.14)
	}
}

/*
 *  These classes are intended to verify that a type hiearchy can be encoded/decoded correctly.
 */
public class RRTestCDOne : RRDynamoCodable, RRStaticDynamoInternal {
	public override nonisolated class var typeId: String? { "test.one" }
	init(with environment: RREngineEnvironment) {
		super.init(with: Config(), in: environment)
	}
	
	required init(from decoder: Decoder) throws {
		try super.init(from: decoder)
	}
	
	public struct Config : RRDynamoCodableConfigurable {
		var oneText: String
		var oneValue: Int
		
		init() {
			oneText  = ""
			oneValue = -1
		}
	}

	public struct State : RRStaticDynamoStateful {
		var oneBool: Bool = true
	}
	public func buildState() -> State {
		return State()
	}
}

public class RRTestCDTwo : RRDynamoCodable, RRStaticDynamoInternal {
	// - no typeId implementation to verify the default behavior.
	
	init(with environment: RREngineEnvironment) {
		super.init(with: Config(), in: environment)
	}
	
	required init(from decoder: Decoder) throws {
		try super.init(from: decoder)
	}
	
	public struct Config : RRDynamoCodableConfigurable {
		var twoFloat: Float
		var twoDate: Date
		
		init() {
			twoFloat = 0.0
			twoDate = .init()
		}
	}

	public struct State : RRStaticDynamoStateful {
		var twoBool: Bool = false
	}
	public func buildState() -> State {
		return State()
	}
}
