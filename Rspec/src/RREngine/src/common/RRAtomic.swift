//
//  RRAtomic.swift
//  RREngine
// 
//  Created on 7/15/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine

protocol RRAtomicCompatible : Sendable {
	func withLock<R>(_ body: () -> R) -> R
	func withLock<R>(_ body: () throws -> R) throws -> R
}

/*
 *  Convenience class for implementing safe non-isolated data.
 *  - this *cannot* be a property wrapper because it would lose
 *    its actor isolation when not a constant value.
 */
class RRAtomic<T: Any> : RRAtomicCompatible, ObservableObject, @unchecked Sendable {
	// - the represented value.
	nonisolated var value: T {
		get { cs.withLock({ _value }) }
		set { cs.withLock({ _value = newValue }) }
	}
		
	/*
	 *  Atomically set the new value and retrieve the prior one.
	 */
	nonisolated func valueThenChanged(to newValue:T) -> T {
		return cs.withLock {
			let ret = _value
			_value  = newValue
			return ret
		}
	}
	
	/*
	 *  Initialize the object.
	 */
	init(_ value: T) {
		self._value = value
	}
	
	// - use the atomic for a critical section
	func withLock<R>(_ body: () -> R) -> R { cs.withLock(body) }
	func withLock<R>(_ body: () throws -> R) throws -> R { try cs.withLock(body) }
	
	// - internal
	@Published private var _value: T
	private var subject: PassthroughSubject<RRAtomic<T>, Never>?
	private let cs: NSRecursiveLock = .init()
}

/*
 *  Convenience class for weak variants.
 *  - there's no publisher here because theres no didSet of the weak value
 *    when its reference goes to zero.
 */
class RRWeakAtomic<T: AnyObject> : RRAtomicCompatible, @unchecked Sendable {
	// - the represented value.
	nonisolated var value: T? {
		get { cs.withLock({ _value }) }
		set { cs.withLock({ _value = newValue }) }
	}
	
	/*
	 *  Initialize the object.
	 */
	init(_ value: T?) {
		self._value = value
	}
	
	// - use the atomic for a critical section
	func withLock<R>(_ body: () -> R) -> R { cs.withLock(body) }
	func withLock<R>(_ body: () throws -> R) throws -> R { try cs.withLock(body) }
	
	// - internal
	private weak var _value: T?
	private let cs: NSRecursiveLock = .init()
}
