//
//  RRStatefulProcessor.swift
//  RREngine
// 
//  Created on 7/26/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  Stateful processors are entities that acquire non-trivial state
 *  during the course of directed or autonomous processing and often
 *  require methodical shutdown.
 *  DESIGN:  Shutdown *must* work the first time it is tried or die hard
 * 			 trying. There is no failure path to recover or retry because
 *  		 it is permitted to occur during object deinit when there is
 *  		 only a single opportunity.
 */
protocol RRStatefulProcessor {
	// - the core requirement of a stateful processor is the need to shutdown.
	@discardableResult func shutdown() async -> RRShutdownResult
}
extension RRStatefulProcessor where Self: RRLoggableCategory {
	// - consistent shutdown logging
	func logBeginShutdown(_ desc: String) { Self.log.debug("Beginning shutdown of \(desc, privacy: .public).") }
	func logEndShutdown(_ desc: String, result: RRShutdownResult) {
		if let err = result.asError {
			Self.log.error("Failed shutdown of \(desc, privacy: .public).  \(err.localizedDescription, privacy: .public)")
		}
		else {
			Self.log.debug("Completed shutdown of \(desc, privacy: .public) successfully.")
		}
	}
}

/// Describes the outcome of a subsystem shutdown attempt.
public typealias RRShutdownResult = ResultBool
extension RRShutdownResult {
	// - aggregate a result, favoring an error if any appears.
	func appending(_ result: RRShutdownResult) -> RRShutdownResult {
		guard case .success = self else { return self }
		if case .failure(_) = result {
			return result
		}
		return .success
	}
	
	// - aggregate a result onto the current value.
	@discardableResult mutating func append(_ result: RRShutdownResult?) -> RRShutdownResult {
		if let result = result {
			self = self.appending(result)
		}
		return self
	}
}

///  Describes the processing behavior of a RRouted subsystem.
public enum RROperatingStatus : String {
	///  The subsystem is processing.
	case running			= "Running"
	
	///  The subsystem is online, but not processing.
	case paused				= "Paused"
	
	///  The subsystem has started its shutdown operations.
	case shuttingDown		= "Shutting Down"
	
	///  The subsystem has failed to shut down and is in an undefined state.
	case failed				= "Failed"
	
	///  The subsystem is no longer processing.
	case offline			= "Offline"
}
