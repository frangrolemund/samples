//
//  RRVersionTests.swift
//  RREngineTests
// 
//  Created on 10/5/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import XCTest
import RREngine

final class RRVersionTests: XCTestCase {
	/*
	 *  Verify the basic parser works.
	 */
	func testParsing() throws {
		assertEquivalentVersion("1", to: 1, 0, patch: 0)
		assertEquivalentVersion("1.0", to: 1, 0, patch: 0)
		assertEquivalentVersion("1.0.0", to: 1, 0, patch: 0)
		assertEquivalentVersion("1.0.0", to: 1, 0, patch: 0)
		
		assertEquivalentVersion("5.9", to: 5, 9, patch: 0)
		assertEquivalentVersion("0.2.1", to: 0, 2, patch: 1)
	}
	
	/*
	 *  Verify that errors are caught.
	 */
	func testErrorDetection() throws {
		assertBadArguments("a.b.c")
		assertBadArguments("1.2.3.4")
		assertBadArguments("4.-1")
	}
	
	/*
	 *  Verify that parsing text results in the provided version.
	 */
	private func assertEquivalentVersion(_ text: String, to major: UInt, _ minor: UInt, patch: UInt) {
		let sv = try? RRVersion(with: text)
		XCTAssertNotNil(sv)
		XCTAssertEqual(sv!.major, major)
		XCTAssertEqual(sv!.minor, minor)
		XCTAssertEqual(sv!.patch, patch)
	}
	
	/*
	 *  Verify that the bad format error is thrown.
	 */
	private func assertBadArguments(_ text: String) {
		do {
			let _ = try RRVersion(with: text)
		}
		catch {
			XCTAssertEqual(error as? RRError, .badArguments)
		}
	}
}
