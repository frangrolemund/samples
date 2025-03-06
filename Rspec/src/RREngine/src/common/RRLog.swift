//
//  RRLog.swift
//  RREngine
// 
//  Created on 7/14/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import OSLog

/*
 *  Identifies a subsystem as providing consistent logging facilities.
 */
protocol RRLoggableCategory {
	static var logCategory: String? { get }
}

extension RRLoggableCategory {
	static var log: Logger {
		.init(subsystem: "com.realproven.RREngine", category: Self.logCategory ?? String(describing: self))
	}
	var log: Logger { Self.log }
}
