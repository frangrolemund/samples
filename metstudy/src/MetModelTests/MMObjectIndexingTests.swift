//
//  MMObjectIndexingTests.swift
//  MetModelTests
// 
//  Created on 1/18/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import XCTest
@testable import MetModel

/*
 *  Verifies that the indexing of the MetObjects.csv file is correct.
 */
final class MMObjectIndexingTests: XCTestCase {
	/*
	 *  Basic behavior with a small example.
	 */
    func testSmallFile() async throws {
		self.log.info("Parsing the object file.")
		let sfURL = testDataURLForFile("MetObjects-Small.csv")
		let miTmp = try await MetModel.readIndex(from: sfURL)
		XCTAssertEqual(miTmp.count, 8)
		
		// - encode/decode to verify it works the whole way through
		self.log.info("Verifying coding behavor...")
		let jData 			  = try encodeJSON(miTmp)
		let mi: MMObjectIndex = try decodeJSON(jData)
		XCTAssertEqual(mi.count, 8)
		
		// - iterator checking.
		self.log.info("Checking the iterator...")
		for i in 0..<mi.count {
			let obj = mi[i]!
			XCTAssertEqual(obj.isPublicDomain, true)		// - the index only exports public domain items.
			print("\(i)  -> \(obj)")
		}
		
		// - spot checking
		self.log.info("Spot checking data...")
		XCTAssertEqual(mi[3]?.objectID, 3)
		XCTAssertEqual(mi[2]?.objectID, 8)
		
		XCTAssertEqual(mi[0]?.accessionNumber, "1980.264.5")
		XCTAssertEqual(mi[4]?.accessionNumber, "67.265.12")
				
		XCTAssertEqual(mi[4]?.isHighlight, true)
		XCTAssertEqual(mi[7]?.isHighlight, false)
		
		// ...quick invalid
		XCTAssertEqual(mi[12]?.isHighlight, nil)
		
		XCTAssertEqual(mi[2]?.isTimelineWork, false)
		XCTAssertEqual(mi[6]?.isTimelineWork, true)
		
		XCTAssertEqual(mi[4]?.department, "The American Wing")
		
		XCTAssertEqual(mi[0]?.accessionYear, 1980)
		XCTAssertEqual(mi[3]?.accessionYear, 1967)
		XCTAssertEqual(mi[5]?.accessionYear, nil)
		
		XCTAssertEqual(mi[7]?.objectName, "Rare Coin")
		XCTAssertEqual(mi[2]?.objectName, nil)
		
		XCTAssertEqual(mi[0]?.title, nil)
		XCTAssertEqual(mi[3]?.title, "Two-and-a-Half Dollar Coin")
		
		XCTAssertEqual(mi[5]?.culture, nil)
		XCTAssertEqual(mi[2]?.culture, "American")
		
		XCTAssertEqual(mi[0]?.artistDisplayName, "Christian Gobrecht")
		XCTAssertEqual(mi[7]?.artistDisplayName, nil)
		
		XCTAssertEqual(mi[1]?.artistDisplayBio, "American, Delaware County, Pennsylvania 1794–1869 Philadelphia, Pennsylvania")
		XCTAssertEqual(mi[4]?.artistDisplayBio, nil)
		
		XCTAssertEqual(mi[0]?.objectBeginDate, 1850)
		XCTAssertEqual(mi[3]?.objectBeginDate, 1909)
		
		XCTAssertEqual(mi[0]?.objectEndDate, 1901)
		XCTAssertEqual(mi[3]?.objectEndDate, 1927)
		
		XCTAssertEqual(mi[7]?.medium, nil)
		XCTAssertEqual(mi[1]?.medium, "Gold")
		
		XCTAssertEqual(mi[4]?.linkResource, "http://www.metmuseum.org/art/collection/search/6")
		XCTAssertEqual(mi[6]?.linkResource, "http://www.metmuseum.org/art/collection/search/9")
		
		XCTAssertEqual(mi[4]?.tags, [])
		XCTAssertEqual(mi[2]?.tags.contains("Eagles"), true)
		XCTAssertEqual(mi[2]?.tags.contains("Men"), true)
		XCTAssertEqual(mi[2]?.tags.contains("Profiles"), true)
		
		self.log.info("Setting an invalid cache directory...")
		let url = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appending(path: "/\(UUID().uuidString)")
		XCTAssertThrowsError(try mi.setCacheRootDirectory(url: url))
		
		self.log.info("Setting valid cache directory...")
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		try mi.setCacheRootDirectory(url: url)
    }
	
	/*
	 *  Basic behavior with a medium example.
	 */
	func testMediumFile() async throws {
		self.log.info("Parsing the object file.")
		let sfURL = testDataURLForFile("MetObjects-Med.csv")
		let miTmp = try await MetModel.readIndex(from: sfURL)
		
		self.log.info("Verifying coding behavor...")
		let jData 			  = try encodeJSON(miTmp)
		let mi: MMObjectIndex = try decodeJSON(jData)
		XCTAssertEqual(mi.count, 1342)
		
		// - iterator checking.
		self.log.info("Checking the iterator...")
		for i in 0..<mi.count {
			let obj = mi[i]!
			XCTAssertEqual(obj.isPublicDomain, true)		// - the index only exports public domain items.
			print("\(i)  -> \(obj)")
		}
		
		self.log.info("Spot checking...")
		// ..this second item is special because it extends across multiple rows with escaped newlines
		XCTAssertEqual(mi[1309]?.tags.count, 4)
		XCTAssertEqual(mi[1309]?.tags.contains("Animals"), true)
		XCTAssertEqual(mi[1309]?.tags.contains("Garlands"), true)
		XCTAssertEqual(mi[1309]?.tags.contains("Birds"), true)
		XCTAssertEqual(mi[1309]?.tags.contains("Men"), true)
	}
}
