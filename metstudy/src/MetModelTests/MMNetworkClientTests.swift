//
//  MMNetworkClientTests.swift
//  MetModelTests
// 
//  Created on 2/24/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import XCTest
@testable import MetModel

/*
 *  Verifyt the networking client behavior.
 */
final class MMNetworkClientTests: XCTestCase {
	/*
	 *  Verify the object API behavior.
	 */
	func testObjectAPI() async throws {
		let nc = MMNetworkClient()
		
		// ...choose objects that exercise the different attributes' variability
		//    without failing to decode the data.
		let TestObjectIds: [MMObjectIdentifier] = [45734, 2, 61919, 692523]
		for oId in TestObjectIds {
			let ret = try await nc.queryMetArtObject(identifiedBy: oId).get()
			MMLog.info("Retrieved object \(String(describing: ret))")
		}
	}
	
	/*
	 *  Verify the sample exhibit can be retrieved.
	 */
	func testSampleExhibit() async throws {
		let exhibit = MetModel.sampleExhibit
		let pData	= await exhibit?.primaryImage
		XCTAssertNotNil(pData)
	}
}
