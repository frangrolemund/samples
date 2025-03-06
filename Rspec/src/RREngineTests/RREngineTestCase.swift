//
//  RREngineTestCase.swift
//  RREngineTests
// 
//  Created on 8/26/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import OSLog
import XCTest
import RREngine

// - convenience utilities for testing.
class RREngineTestCase : XCTestCase {
	let log: Logger = .init(subsystem: "com.realproven.RREngine", category: "UnitTest")
	
	/*
	 *  Finish up the test.
	 */
	override func tearDown() {
		super.tearDown()
		
		for td in testDirectories {
			log.info("Removing test directory: \(td.absoluteString)")
			do {
				try FileManager.default.removeItem(at: td)
			}
			catch {
				log.error("Failed to remove the diretory.  \(error.localizedDescription)")
			}
		}
	}
	
	// - internal
	private var testDirectories: [URL] = []
}

/*
 *  Utilities.
 */
extension RREngineTestCase {
	/*
	 *  Create a common engine instance.
	 */
	@MainActor
	func createEngine() -> RREngine {
		let ret = RREngine()
		ret.start()
		return ret
	}
	
	/*
	 *  Load an engine from filewrapper data.
	 */
	@MainActor
	func loadEngine(from fileWrapper: FileWrapper) throws -> RREngine {
		let ret = try RREngine.load(from: fileWrapper)
		ret.start()
		return ret
	}
	
	/*
	 *  Return a custom test directory.
	 */
	func createTestDirectory() throws -> URL {
		let tdU = URL(fileURLWithPath: "/tmp").appending(path: "test-dir-\(RRIdentifier().briefId)")
		try FileManager.default.createDirectory(at: tdU, withIntermediateDirectories: true)
		testDirectories.append(tdU)
		self.log.info("Created test directory at: \(tdU.absoluteString)")
		return tdU
	}
	
	/*
	 *  Wait until the modeled object satisfies the provided condition.
	 */
	func observableChange<O: ObservableObject>(for model: O, from line: Int = #line, until condition: @escaping (_ model: O) -> Bool) async {
		log.info("...waiting for change of \(String(describing: type(of: model)), privacy: .public) [@\(line, privacy: .public)]")
		
		// - ensure that we don't block the main thread from receiving updates on the Combine queue.
		return await withUnsafeContinuation({ continuation in
			Task.detached {
				// ...if it is already good.
				guard !condition(model) else {
					continuation.resume(returning: ())
					return
				}
				
				let t = Task(priority: .background) {
					try await Task.sleep(for:.seconds(30))
					guard !Task.isCancelled else { return }
					XCTAssertTrue(false, "Observable time out.")
				}
				
				// ...I've noticed occasional crashes in this path that make me wonder
				//    if this subscription is firing more than once and resuming
				//    the continuation more than once.  The docs indicate that is
				//    not recommended (strongly).
				var didFire: Bool = false
				let sub = model.objectWillChange.receive(on: RunLoop.main).sink { _ in
					if !didFire, condition(model) {
						didFire = true
						t.cancel()
						continuation.resume(returning: ())
					}
				}
				
				try? await t.value
				sub.cancel()
			}
		})
	}
}
