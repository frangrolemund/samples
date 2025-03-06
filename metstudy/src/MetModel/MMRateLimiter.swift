//
//  MMRateLimiter.swift
//  MetModel
// 
//  Created on 2/23/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  The purpose of this actor is to provide objectively-correct 
 *  rate limiting for requests of the MetArt back-end API, which
 *  they've specified on their API site https://metmuseum.github.io as:
 
 *		> Please limit request rate to 80 requests per second.
 */
actor MMRateLimiter {
	static let MetArtLimit: UInt = 80
	
	let requestsPerSecond: UInt
	var isSchedulerRunning: Bool { self.scheduler != nil }
	
	/*
	 *  Initialize the actor.
	 */
	init(requestsPerSecond: UInt) {
		assert(requestsPerSecond > 0, "Unexpected non-limit.")
		MMLog.info("Configuring model request rate limiter for \(requestsPerSecond, privacy: .public)rps.")
		self.requestsPerSecond = requestsPerSecond
		self.reqCount 		   = 0
		self.waitPending  	   = []
	}
	
	/*
	 *  Wait for rate-limited access to the shared resource.
	 */
	func waitForAccess() async {
		guard !canRunWithCurrentCapacity() else { return }
		await self.scheduledWait()
	}

		
	// - internal
	private typealias VoidTask = Task<Void, Never>
	private var scheduler: VoidTask?
	private var reqCount: Int
	private var waitPending: [VoidTask]
}

/*
 *  Internal implementation
 */
extension MMRateLimiter {
	/*
	 *  The scheduler ensures orderly access to the shared resource 
	 *  in with a FIFO algorithm.
	 */
	private func createSchedulerIfNecessary() {
		guard self.scheduler == nil else { return }
		self.scheduler = Task {[weak self] () in
			while true {
				try? await Task.sleep(for: .seconds(1))				// - must be once per second
				guard !Task.isCancelled, let self = self else { break }
				await self.runSchedulerCycle()
			}
		}
	}
	
	/*
	 *  Executes the scheduler activities.
	 */
	private func runSchedulerCycle() {
		// - reset the request count and enqueue what is waiting.
		self.reqCount = 0

		// - nothing to do, then pause the scheduler.
		guard !self.waitPending.isEmpty else {
			self.scheduler?.cancel()
			self.scheduler = nil
			return
		}
		
		// - to free the waiting tasks, just cancel them
		while !self.waitPending.isEmpty, canRunWithCurrentCapacity() {
			let first = waitPending.removeFirst()
			first.cancel()
		}
	}
	
	/*
	 *  Checks if the current
	 */
	private func canRunWithCurrentCapacity() -> Bool {
		if self.reqCount < self.requestsPerSecond {
			self.reqCount += 1
			return true
		}
		return false
	}
	
	/*
	 *  The inbound requests have exceeded capacity, schedule a wait in the
	 *  FIFO queue until capacity becomes available.
	 */
	private func scheduledWait() async {
		let ret: VoidTask = Task {
			while !Task.isCancelled  {
				try? await Task.sleep(for: .milliseconds(250))
			}
		}
		self.waitPending.append(ret)
		self.createSchedulerIfNecessary()
		await ret.value
	}
}
