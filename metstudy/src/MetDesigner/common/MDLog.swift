//
//  MDLog.swift
//  MetDesigner
// 
//  Created on 1/26/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import OSLog

/*
 *  App logger.
 */
struct MDLog {
	private static let _log: Logger = .init(subsystem: "com.realproven.MetDesigner", category: "MetDesigner")
	
	/*
	 *  Print an informational log message.
	 */
	static func info(_ msg: String) {
		_log.info("INFO: \(msg, privacy: .public)")
	}
	
	/*
	 *  Print a warning log message.
	 */
	static func warn(_ msg: String) {
		_log.warning("WARN: \(msg, privacy: .public)")
	}

	/*
	 *  Print an error log message.
	 */
	static func error(_ msg: String) {
		_log.error("ERROR: \(msg, privacy: .public)")
	}
	
	/*
	 *  Print a fatal-type log message.
	 */
	static func alert(_ msg: String) {
		_log.critical("ALERT: \(msg, privacy: .public)")
	}
}
