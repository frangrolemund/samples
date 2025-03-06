//
//  RREngine.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import OSLog

/// The organizing processor for a RRouted repository.
///
/// The engine is inspired by experience like Smalltalk or spreadsheets in the way
/// they are _always on_ and never started or stopped.  The repository is a living
/// experience with traffic and behavior that is changed gradually from both the
/// inside and outside of the engine interface.'
///
/// The engine is paused by default when first initialized or loaded and must
/// be start()-ed before it will begin processing.
///
@MainActor
public final class RREngine : ObservableObject, RRStatefulProcessor {
	/// The operating version of the engine.
	public static let version: RRVersion = .init(0, 1, 0)
	
	///
	/// Initialize the object.
	///
	nonisolated public convenience init() {
		self.init(env: .init())
	}
	
	///
	///  Load an engine instance from a repository.
	///
	static nonisolated public func load(from repo: FileWrapper) throws -> RREngine {
		let env = try RREngineSnapshot.loadFromFileWrapper(repo)
		return RREngine(env: env)
	}
	
	///
	///  Temporarily stops engine processing and system interaction.
	///
	public func setPaused(_ isPaused: Bool) {
		//  DESIGN:  The purpose of this is to primarily support _non-conflicting engine instances_ with
		// 	 		 the same resource assignments to be instantiated together.  Specifically with
		//			 shared network ports, databases, etc. it doesn't necessarily make sense to support
		// 			 pausing an initialized file descriptor or similar because the system won't allow that
		// 	 		 to occur anyway.  Pausing is a shorthand for ensuring there are no conflicts without
		// 			 reconfiguring any of it.
		guard self.env.isEnginePaused != isPaused else { return }
		self.log.info("\(isPaused ? "Pausing" : "Unpausing", privacy: .public) the engine operation for repository \(self.repositoryId.briefId, privacy: .public).")
		self.objectWillChange.send()
		self.env.setEnginePaused(isPaused)
	}
	
	///
	///  Start engine processing.
	///
	public func start() {
		guard !wasStarted else { return }
		wasStarted = true
		setPaused(false)
	}
	
	///
	///  Shut down the engine.
	///
	@discardableResult public func shutdown() async -> RRShutdownResult {
		return await env.shutdown()
	}
	
	/*
	 *  Initialize the engine.
	 */
	nonisolated private init(env: RREngineEnvironment) {
		self.env = env
	}
	
	//  - internal.
	private let env: RREngineEnvironment
	private var wasStarted: Bool = false
}

/*
 *  Internal
 */
extension RREngine {
	// - general engine logger
	var log: Logger { self.env.log }
}

/*
 *  Accessors.
 */
extension RREngine {
	///  The unique identifier of the associated repository.
	public var repositoryId: RRIdentifier { self.env.repositoryId }
	
	///  The running status of the engine.
	public var operatingStatus: RROperatingStatus { self.env.operatingStatus }
	
	///  The local network management facilities for engine ingress.
	public var firewall: RRFirewall { self.env.firewall }
	
	///  Create a snapshot of the current engine configuration.
	nonisolated public func snapshot() throws -> RREngineSnapshot { try self.env.snapshot() }
	
	///  Save the engine to the profiled repository URL.
	nonisolated public func saveTo(url: URL, originalContentsURL docName: URL? = nil) throws {
		let snap = try snapshot()
		let fw 	 = try snap.saveToFileWrapper()
		try fw.write(to: url, options: [.atomic, .withNameUpdating], originalContentsURL: docName)
	}
}

/*
 *   Node management.
 */
extension RREngine {
	/*
	 *  DEBUG: In the absence of nodes, add a port temporarily for testing.
	 */
	@MainActor public func debugAddHTTPPort() {
		guard self.operatingStatus == .running else { return }
		self.env.debugAddHTTPPort()
	}
}
