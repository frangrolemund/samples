//
//  RRouted.swift
//  RRouted
// 
//  Created on 9/30/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import OSLog
import SwiftUI
import RREngine

/*
 *  The app-wide constants and definitions.
 */
final class RRouted {
	// - general-purpose definitions
	static let appBundleId: String = "com.realproven.rrouted"
	static var myBundle: Bundle {
		if _bundle == nil {
			_bundle = Bundle.allBundles.first(where: {$0.bundleIdentifier == appBundleId }) ?? Bundle.main
		}
		return _bundle!
	}
	static let log: Logger = .init(subsystem: appBundleId, category: "App")
	
	// - operating limits
	static let limits: Limits = .init()
	
	// - directory structure
	static let directories: Directories = .init()
	
	// - brand
	static let brand: Branding = .init()
	
	// - localization
	static let localization: Localization = .init()
	
	// - internal
	static private var _bundle: Bundle?
}

/*
 *  Categories of constants.
 */
extension RRouted {
	/*
	 *  Limits enforced within the app experience while using the engine.
	 */
	struct Limits {
		let MinMaxNetworkPortValues: ClosedRange<NetworkPortValue> = 1024...65535
		let MaxNetworkPortBacklog: UInt16 						   = 32
	}
	
	/*
	 *  Common directory paths used for app storage.
	 */
	class Directories {
		var applicationSupport: URL {
			if _applicationSupport == nil {
				_applicationSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			}
			assert(_applicationSupport != nil, "Unexpected missing application support directory!")
			return _applicationSupport!
		}
		
		var setttingsDirectory: URL {
			if _applicationSupport == nil {
				var newDir = self.applicationSupport
				newDir.append(path: "RRSettings")
				createDirectory(at: newDir)
				self._settingsDirectory = newDir
			}
			return _settingsDirectory!
		}
		
		/*
		 *  Attempt to create a directory at the given location.
		 */
		@discardableResult private func createDirectory(at url: URL) -> Bool {
			do {
				try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
				return true
			}
			catch {
				RRouted.log.error("Failed to create the common app directory at \(url.absoluteString, privacy: .public)")
				return false
			}
		}
		
		// - cached instances.
		private var _applicationSupport: URL?
		private var _settingsDirectory: URL?
	}
		
	/*
	 *  App style and brand.
	 */
	struct Branding {
		let disabledColor: Color = .gray
		let warningColor: Color  = .orange
		let errorColor: Color	 = .red
		let okColor: Color		 = .green
	}
	
	/*
	 *  Localization constants for common terms.
	 */
	struct Localization {
		let offline = LocalizedStringKey("Offline")
		let degraded = LocalizedStringKey("Partially Online")
		let error = LocalizedStringKey("Error")
		let online = LocalizedStringKey("Online")
	}
}
