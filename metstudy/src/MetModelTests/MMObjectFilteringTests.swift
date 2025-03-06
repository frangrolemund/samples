//
//  MMObjectFilteringTests.swift
//  MetModelTests
// 
//  Created on 2/4/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import XCTest
import MetModel

/*
 *  Verifies the behavior while filtering an object index.
 */
final class MMObjectFilteringTests: XCTestCase {
	/*
	 *  Verify that an index can return a collection representing all references.
	 */
	func testFullIndexFilter() async throws {
		self.log.info("Parsing the object file.")
		let sfURL = testDataURLForFile("MetObjects-Med.csv")
		let miTmp = try await MetModel.readIndex(from: sfURL)
		
		// - retrieve a default index wsith the full object list
		let fullEC = try await miTmp.filtered(by: nil)
		XCTAssertEqual(fullEC.count, miTmp.count)
		
		// ...verify it matches what the index reports and has no
		//    problems with random access.
		let randIndices = (0..<fullEC.count).indices.shuffled()			// - to verify random access.
		for idx in randIndices {
			let ecItem = fullEC[idx]
			let ogItem = miTmp[idx]
			XCTAssertEqual(ecItem.id, ogItem?.id)
		}
		
		// encode the index and the context and try again
		let miJSON = try encodeJSON(miTmp)
		let ctxJSON = try encodeJSON(fullEC.context)
		
		let miTmp2: MMObjectIndex = try decodeJSON(miJSON)
		let ctx2: MMFilterContext = try decodeJSON(ctxJSON)
		let fullEC2 = try await miTmp2.filtered(using: ctx2)
		XCTAssertEqual(fullEC.count, fullEC2.count)
		
		for idx in 0..<fullEC.count {
			XCTAssertEqual(fullEC[idx].objectID, fullEC2[idx].objectID)
		}
	}
	
	/*
	 *  Search for text in the content.
	 */
	func testBasicSearch() async throws {
		self.log.info("Parsing the small index file.")
		let msURL = testDataURLForFile("MetObjects-Small.csv")
		let msIdx = try await MetModel.readIndex(from: msURL)
		
		self.log.info("...Searching")
		let msRes = try await msIdx.filtered(by: .init(searchText: "two"))
		XCTAssertEqual(msRes.count, 6)
		print("...Found \(msRes.count) rows.")
		
		self.log.info("Parsing the medium index file.")
		let mmURL = testDataURLForFile("MetObjects-Med.csv")
		let mmIdx = try await MetModel.readIndex(from: mmURL)
		
		self.log.info("..Searching")
		let mmRes = try await mmIdx.filtered(by: .init(searchText: "pressed"))
		XCTAssertEqual(mmRes.count, 119)
		print("...Found \(mmRes.count) rows.")
	}
	
	/*
	 *  Verify text matching rules can apply 'all' or 'any' criteria to the
	 *  search elements.
	 */
	func testSearchRules() async throws {
		self.log.info("Parsing the small index file.")
		let msURL = testDataURLForFile("MetObjects-Small.csv")
		let msIdx = try await MetModel.readIndex(from: msURL)
		
		// ...all records that include the word 'coin'
		let fFull = try await msIdx.filtered(by: .init(MMFilterCriteria(searchText: "coIN")))
		XCTAssertEqual(fFull.count, 8)
		
		// ...one dollar coins
		let fOne  = try await msIdx.filtered(by: .init(MMFilterCriteria(searchText: "COin one", matchingRule: .andMatch)))
		XCTAssertEqual(fOne.count, 1)
		
		// ...two dollar coins
		let fTwo  = try await msIdx.filtered(by: .init(MMFilterCriteria(searchText: "COin two", matchingRule: .andMatch)))
		XCTAssertEqual(fTwo.count, 6)
		
		// ...one and two dollar coins
		let fOneTwo  = try await msIdx.filtered(by: .init(MMFilterCriteria(searchText: "COin one two", matchingRule: .orMatch)))
		XCTAssertEqual(fOneTwo.count, 8)
	}
	
	/*
	 *  Verify that searching based on creation date.
	 */
	func testSearchDate() async throws {
		self.log.info("Parsing the small index file.")
		let msURL = testDataURLForFile("MetObjects-Small.csv")
		let msIdx = try await MetModel.readIndex(from: msURL)
		
		let fY1 = try await msIdx.filtered(by: .init(creationYear: 1850))
		XCTAssertEqual(fY1.count, 1)
		
		let fY2 = try await msIdx.filtered(by: .init(creationYear: 1853))
		XCTAssertEqual(fY2.count, 2)
		
		let fY3 = try await msIdx.filtered(by: .init(creationYear: 1927))
		XCTAssertEqual(fY3.count, 6)

		let fY4 = try await msIdx.filtered(by: .init(MMFilterCriteria(searchText: "Gold", creationYear: 1927)))
		XCTAssertEqual(fY4.count, 5)
		
		let fY5 = try await msIdx.filtered(by: .init(creationYear: 1849))
		XCTAssertEqual(fY5.count, 0)
	}
	
	/*
	 *  Measure the performance of search.
	 */
	func testSearchPerformance() async throws {
		self.log.info("Parsing the med-plus index...")
		let sfURL = testDataURLForFile("MetObjects-MedPlus.csv")
		let miTmp = try await MetModel.readIndex(from: sfURL)
		self.log.info("Indexing completed, starting testing.")

		measure {
			let exp = XCTestExpectation()
			Task {
				let ret = try await miTmp.filtered(by: .init(searchText: "former horn chalk wove men"))
				XCTAssertEqual(ret.count, 1)
				exp.fulfill()
			}
			wait(for: [exp])
		}
	}
}
