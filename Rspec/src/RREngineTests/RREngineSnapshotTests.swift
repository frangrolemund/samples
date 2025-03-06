//
//  RREngineSnapshotTests.swift
//  RREngineTests
// 
//  Created on 10/17/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import XCTest
@testable import RREngine

/*
 *  Verify the engine snapshotting behavior.
 */
@MainActor
final class RREngineSnapshotTests: RREngineTestCase {
	/*
	 *  Verify basic principles of snapshotting.
	 */
    func testBasicPersistence() async throws {
		// ...build the test data
		let engine = createEngine()

		engine.debugAddHTTPPort()
		engine.debugAddHTTPPort()
		engine.debugAddHTTPPort()
		XCTAssertEqual(engine.firewall.ports.count, 3)
		
		// ...save the data
		let tDir = try createTestDirectory()
		let docName = tDir.appending(component: "rrengine.doc")

		try engine.saveTo(url: docName)
		let fwBase = try FileWrapper(url: docName)
				
		// ...confirm the file layout
		try verifyJSONFile(in: docName, path: "manifest.json")
		for p in engine.firewall.ports {
			try verifyJSONFile(in: docName, path: "nodes/\(p.id).json")
		}
		
		// ...update the data
		engine.debugAddHTTPPort()
		XCTAssertEqual(engine.firewall.ports.count, 4)
		let snapshot2 = try engine.snapshot()
		let fwAlt = try snapshot2.saveToFileWrapper(withExisting: fwBase)
		try fwAlt.write(to: docName, options: [.atomic, .withNameUpdating], originalContentsURL: docName)
		try verifyJSONFile(in: docName, path: "manifest.json")
		for p in engine.firewall.ports {
			try verifyJSONFile(in: docName, path: "nodes/\(p.id).json")
		}
		
		// - reload into another engine
		let fwLoad = try FileWrapper(url: docName)
		let engine2 = try loadEngine(from: fwLoad)
		
		// ...verify the content.
		XCTAssertEqual(engine.repositoryId, engine2.repositoryId)
		XCTAssertEqual(engine.firewall.ports.count, engine2.firewall.ports.count)
		for p in engine.firewall.ports {
			let p2 = engine2.firewall.ports.first(where: {$0.id == p.id})
			XCTAssertNotNil(p2)
		}
		
		// - update the new data, which should add a non .data cache item.
		engine2.debugAddHTTPPort()
		XCTAssertEqual(engine2.firewall.ports.count, 5)
		let snapshot3 = try engine2.snapshot()
		let fwMemorex = try snapshot3.saveToFileWrapper(withExisting: fwLoad)	// - use existing to test the optimization of saving
		try fwMemorex.write(to: docName, options: [.atomic, .withNameUpdating], originalContentsURL: docName)
		
		// ...reload and verify this last one
		let fwLoad2 = try FileWrapper(url: docName)
		let engine3 = try RREngine.load(from: fwLoad2)
		XCTAssertEqual(engine2.repositoryId, engine3.repositoryId)
		XCTAssertEqual(engine2.firewall.ports.count, engine3.firewall.ports.count)
		for p in engine2.firewall.ports {
			let p2 = engine3.firewall.ports.first(where: {$0.id == p.id})
			XCTAssertNotNil(p2)
		}
    }
	
	/*
	 *  Verify the file at the given path offset is JSON.
	 */
	private func verifyJSONFile(in doc: URL, path: String) throws {
		let target = doc.appending(path: path)
		XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
		
		let fData = try Data(contentsOf: target)
		let jObj  = try JSONSerialization.jsonObject(with: fData)
		XCTAssertNotNil(jObj as? NSDictionary)
	}
}
