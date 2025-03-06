//
//  MMRateLimiterTests.swift
//  MetModelTests
// 
//  Created on 2/24/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import XCTest
@testable import MetModel

/*
 *  Verify the behavior of the rate limiter.
 */
final class MMRateLimiterTests: XCTestCase {
	/*
	 *  Verify that the rate limiter gates progress predictably.
	 */
	func testRateLimiting() async throws {
		// - this aims to apply black-box testing against a
		//   rate limiter actor, knowing only the rate we desire
		//   and the work we send against it.  If it works, the
		//   results should be very predictable.
		
		// - to not have this test run forever, we'll assume
		//   no less than 3 seconds total to complete this.
		let TotalItems: Int = 31					// - must be 1 more than what is evenly divisible by the test time so that it has a final cycle.
		let TargetTestTime: TimeInterval = 3.0
		let rLim = MMRateLimiter(requestsPerSecond: UInt(Double(TotalItems) / TargetTestTime))
		
		// - two rounds so that
		for _ in 0..<2 {
			let start = Date()
			
			await withTaskGroup(of: Void.self) { tGroup in
				for i in 0..<TotalItems {
					tGroup.addTask {
						self.log.info("Scheduling task \(i, privacy: .public)...")
						await rLim.waitForAccess()
						self.log.info("Completed task \(i, privacy: .public).")
					}
				}
				
				await tGroup.waitForAll()
			}
			let end = Date()
			
			let elapsed = end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
			self.log.info("Time elapsed --> \(elapsed, privacy: .public)")
			XCTAssertTrue(elapsed >= TargetTestTime && elapsed < (TargetTestTime + 0.5))
			
			var sRun = await rLim.isSchedulerRunning
			XCTAssertTrue(sRun)
			self.log.info("Rate limiting scheduler is still online.")
			
			// ... ensure the scheduler runs one more time to detect the empty queue
			try await Task.sleep(for: .milliseconds(1100))
			
			// ...at this point the ratelimiter's backlog should be emnpty and its scheduler paused.
			sRun = await rLim.isSchedulerRunning
			XCTAssertFalse(sRun)
			self.log.info("Rate limiting scheduler is now offline.")
		}
	}
}
