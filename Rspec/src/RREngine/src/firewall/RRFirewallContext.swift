//
//  RRFirewallContext.swift
//  RREngine
// 
//  Created on 8/15/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import NIOCore
import NIOPosix

/*
 *  Provides common resources shared amongst firewall ports.
 */
actor RRFirewallContext : RRStatefulProcessor, RRLoggableCategory {
	static var logCategory: String? = "Firewall"
	
	/*
	 *  Initialize the object.
	 */
	init() {
		Task.detached {	let _ = await self.eventLooopGroup }
	}
	
	/*
	 *  Bootstrap a new server instance.
	 */
	func bootstrapServer(toPort portValue: NetworkPortValue, with block: @Sendable (_ bootstrap: ServerBootstrap) -> ServerBootstrap) async -> Result<Channel, Error> {
		let bootstrap = ServerBootstrap(group: self.eventLooopGroup)
		do {
			let serverChannel = try await block(bootstrap).bind(host: "localhost", port: Int(portValue)).get()
			return .success(serverChannel)
		}
		catch {
			return .failure(error)
		}
	}
	
	/*
	 *  Shut down the firewall environment/
	 */
	func shutdown() async -> RRShutdownResult {
		guard isOnline else { return .success }
		let desc = "the firewall environment"
		self.logBeginShutdown(desc)
		
		let ret: RRShutdownResult
		do {
			try await self.eventLooopGroup.shutdownGracefully()
			isOnline  = false
			self._elg = nil
			ret = .success
		}
		catch {
			ret = .failure(error)
		}
		
		self.logEndShutdown(desc, result: ret)
		return ret
	}
	
	// - internal
	private var isOnline: Bool = true
	private var _elg: MultiThreadedEventLoopGroup?
}

/*
 *  Internal implementation.
 */
extension RRFirewallContext {
	// - the common thread pool for the firewall and its ports.
	private var eventLooopGroup: MultiThreadedEventLoopGroup {
		assert(isOnline, "Detected late usage of event loop.")
		if let elg = self._elg {
			return elg
		}
		let newELG = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
		self._elg  = newELG
		return newELG
	}
}
