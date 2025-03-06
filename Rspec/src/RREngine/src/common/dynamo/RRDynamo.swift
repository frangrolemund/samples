//
//  RRDynamo.swift
//  RREngine
// 
//  Created on 8/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine

/// The fundamental unit of processing in the engine.
///
/// A `dynamo` is a _data generator_ where its initiation and means of generation
/// are dependent on its type.  In most cases a dynamo is more accurately a _data
/// converter_ in that it receives data and then converts/generates new data from
/// that source.
///
/// The design of dynamos embraces the intention for deep support of inspection and
/// control over engine behaviors by combining a UI-facing model with concurrent,
/// internal processing.  Because of this, it must bridge both @MainActor and
/// nonisolated contexts equally.  The intent is that most of the dynamo is accessed
/// via the main thread with selected operations able to be performed on any thread.
@MainActor
public class RRDynamo : ObservableObject, RRStatefulProcessor, RRLoggableCategory, RRIdentifiable {	
	///  The unique identification of the dynamo.
	nonisolated public var id: RRIdentifier { self.data.value!.id }
	nonisolated class var logCategory: String? { return nil }

	// - a unique piece of text describing this instance for shutdown logging
	var shutdownDescriptor: String? { return nil }
	
	/// Publishes modification to the runtime state of the dynamo.
	nonisolated public var statefulPublisher: AnyPublisher<RRDynamo, Never> {
		// ...only create a subject if we need to propagate events.
		if let ss = self.statefulSubject {
			return ss.eraseToAnyPublisher()
		}
		let ss: PassthroughSubject<RRDynamo, Never> = .init()
		self.statefulSubject = ss
		return ss.eraseToAnyPublisher()
	}
	
	/*
	 *  Initialize the object.
	 *  DESIGN: The environment is _required_ here because it coordinates them with the
	 * 			engine and the rest of the dynamos in it.  It is important that it is only stored weakly,
	 * 			however because the environment itself will probably have dynamos it references directly or
	 * 			indirectly.
	 */
	nonisolated internal init(with config: any RRDynamoConfigurable, in environment: RREngineEnvironment, identifier: RRIdentifier? = nil) {
		// - the lock is essential for the dynamo to be able to be used from both MainActor and
		//   nonisolated contexts for compliance with common protocols, integrations with documents, etc.
		self.data.value = .init(id: identifier ?? .init(), operatingStatus: .running, config: config)
		self._env.value = environment
		
		// ...the runtime remains optional because it will be detached to halt processing,
		//    which conveniently allows us to call it on 'self' here and have it use init
		//    parameters.
		self.__runtime = (self as? RRDynamoInternal)?.__buildRuntime(with: environment)
		
		// - it is important that the propagation of events from the configuration changes
		//   are separate from those in the state, which will occur much more frequently for
		//   many dynamo implementations.  Imagine state as the small, trace-like details that
		//   are managed by the runtime that can quickly overwhelm most UIs that aren't ready
		//   for that many updates in a short time period.
		if let runtime = self.__runtime {
			self.applyConfigToRuntime()
			self.__runtimeSub = runtime.statefulPublisher.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] (_) in
				guard let self = self else { return }
				Task {
					await self.runtimeStateHasBeenUpdated()
					self.statefulSubject?.send(self)
				}
			})
			Task { await self.runtimeStateHasBeenUpdated() }
		}
		
		// - ensure the dynamo detects critical changes to the engine environment.
		self.subscribe(to: environment.changePublisher.sink(receiveValue: { changeValue in
			self.environmentWasUpdated(change: changeValue)
		}))
		
		self.dynamoDidLoad()
	}
	
	/*
	 *  The dynamo has loaded and is ready for configuration.
	 *  DESIGN: I think it is important that this is non-isolated so that it can happen
	 * 		    in the same call stack as the initialization, which itself must nonisolated.
	 */
	nonisolated func dynamoDidLoad() {
	}
	
	/*
	 *  The dynamo's configuration was modified.
	 */
	nonisolated func configurationWasUpdated() {
	}
	
	/*
	 *  The engine environment was modified.
	 */
	nonisolated func environmentWasUpdated(change: RREngineEnvironment.ChangeType) {
		if case .enginePaused(let isPaused) = change {
			self.objectWillChange.send()
			dynamoWasPaused(isPaused: isPaused)
			self.pauseRuntime(isPaused)
		}
	}
	
	/*
	 *  The dynamo has changed its paused status.
	 */
	nonisolated func dynamoWasPaused(isPaused: Bool) {
	}
	
	/*
	 *  This method is intended to be called before a subclass modifes state that
	 *  should be interpreted as part of the UI model hiearchy under this dynamo.
	 *  Dynamos that host other dynamos, usually do so in their runtime in order to
	 *  guarantee all dependencies are shut down consistently.
	 */
	nonisolated func runtimeStateWillChangeModel() {
		self.objectWillChange.send()
	}
	
	/*
	 *  The operating state of the runtime has changed.
	 */
	func runtimeStateHasBeenUpdated() {
	}
	
	/*
	 *  Deallocate the dynamo.
	 */
	@discardableResult func shutdown() async -> RRShutdownResult {
		guard let rt = self.__runtime else { return .failure(RRError.notProcessing) }
		
		if let shutdownDesc = shutdownDescriptor {
			self.logBeginShutdown(shutdownDesc)
		}
		
		self.__runtimeSub?.cancel()
		self.__runtimeSub      = nil
		self.__runtime 	       = nil
		self.__operatingStatus = .shuttingDown
		self.runtimeStateHasBeenUpdated()
		let ret 			   = await rt.shutdown()

		if let err = ret.asError {
			self.logFailShutdown(self.shutdownDescriptor ?? String(describing: Self.self), err)
			self.__operatingStatus = .failed
			return ret
		}
		
		self.__operatingStatus = .offline

		if let shutdownDesc = shutdownDescriptor {
			self.logCompleteShutdown(shutdownDesc)
		}
		
		return ret
	}
	
	/*
	 *  Deinitialize the object.
	 */
	deinit {
		guard let rt = self.__runtime else { return }

		// ...shutdown of dynamos is very important and should not be left to
		//    implicit deinitialization behavior.
		let tName = String(describing: type(of: self))
		Task {
			Self.log.debug("Beginning shutdown of orphaned \(tName, privacy: .public).")
			let ret = await rt.shutdown()
			Self.log.debug("\(ret.isOk ? "Completed" : "Failed", privacy: .public) shutdown of orphaned \(tName, privacy: .public).  \(ret.asError?.localizedDescription ?? "", privacy: .public)")
		}
	}
	
	// - internal
	private let data: RRAtomic<Data?> 				    = .init(nil)
	private let _env: RRWeakAtomic<RREngineEnvironment> = .init(nil)
	
	nonisolated internal var __config: (any RRDynamoConfigurable) {
		get { self.data.value!.config }
		set {
			self.data.withLock {
				guard !newValue.equals(self.data.value!.config) else { return }
				self.objectWillChange.send()
				self.data.value?.config = newValue
				applyConfigToRuntime()
				Task { configurationWasUpdated() }
			}
		}
	}
	
	nonisolated internal var environment: RREngineEnvironment {
		let ret = self._env.value
		assert(ret != nil, "Detected premature environment de-initialization.")
		return ret ?? .init()
	}
	
	nonisolated private (set) var __operatingStatus: RROperatingStatus {
		get { (self.data.value?.operatingStatus == .running && self.environment.isEnginePaused) ? .paused : (self.data.value?.operatingStatus ?? .offline) }
		set { self.data.value?.operatingStatus = newValue }
	}
		
	nonisolated var __runtime: (any RRDynamoStatefulManager)? {
		get { data.value?.runtime }
		set { data.value?.runtime = newValue }
	}
	
	nonisolated private var __runtimeSub: AnyCancellable? {
		get { data.value?.runtimeSub }
		set { data.value?.runtimeSub = newValue }
	}
	
	nonisolated private var statefulSubject: PassthroughSubject<RRDynamo, Never>? {
		get { data.value?.statefulSubject }
		set { data.value?.statefulSubject = newValue }
	}
	
	/*
	 *  Retain a Combine token.
	 */
	nonisolated func subscribe(to token: AnyCancellable, as named: String? = nil) {
		data.withLock {
			guard var value = data.value else { return }
			value.genericSubs[named ?? UUID().uuidString + "-auto"] = token
			data.value = value
		}
	}
	
	/*
	 *  Discard a Combine token.
	 */
	nonisolated func unsubscribe(_ name: String) {
		data.withLock {
			guard var value = data.value else { return }
			value.genericSubs.removeValue(forKey: name)
			data.value = value
		}
	}
	
	/*
	 *  Perform an action within the dynamo lock.
	 */
	nonisolated func withLock<T: Any>(block: () -> T) -> T {
		data.withLock { block() }
	}
}

/*
 *  Types
 */
extension RRDynamo {
	/*
	 *  In order to provide a nonisolated interface for some operations, the
	 *  dynamo must organize all its data under a lock because only a guarantee of
	 *  that lock's construction will allow the nonisolated paths to compile.
	 */
	private struct Data {
		let id: RRIdentifier
		var operatingStatus: RROperatingStatus
		var config: (any RRDynamoConfigurable)
		var runtime: (any RRDynamoStatefulManager)?
		var runtimeSub: AnyCancellable?
		var statefulSubject: PassthroughSubject<RRDynamo, Never>?
		var genericSubs: [ String : AnyCancellable] = [:]
	}
}

/*
 *  Internal
 */
extension RRDynamo {
	/*
	 *  Consistent shutdown logging that respects the inheritance hierarchy.
	 *  ...the protocol implementations did not understand inheritance.
	 */
	private func logBeginShutdown(_ desc: String) { Self.log.debug("Beginning shutdown of \(desc, privacy: .public).") }
	private func logFailShutdown(_ desc: String, _ error: Error) { Self.log.error("Failed shutdown of \(desc, privacy: .public).  \(error.localizedDescription, privacy: .public)")	}
	private func logCompleteShutdown(_ desc: String) { Self.log.debug("Completed shutdown of \(desc, privacy: .public) successfully.") }
	
	/*
	 *  Update the runtime with the current configuration.
	 */
	nonisolated private func applyConfigToRuntime() {
		(self as? any RRActiveDynamoInternal)?.__applyConfigToRuntime()
	}
	
	/*
	 *  Pause/unpause the runtime.
	 */
	nonisolated private func pauseRuntime(_ isPaused: Bool) {
		(self as? any RRActiveDynamoInternal)?.__setPaused(isPaused)
	}
}
