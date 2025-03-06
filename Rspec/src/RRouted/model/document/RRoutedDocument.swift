//
//  RRoutedDocument.swift
//  RRouted
// 
//  Created on 9/19/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import RREngine

// - export the custom type.
extension UTType {
	static var rroutedFlow: UTType {
		UTType(exportedAs: "com.realproven.rrouted.spec")
	}
}

/*
 *  Defines the app document file format.
 *  DESIGN:  RRouted is a document-based app, capturing all configuration
 *  		 behavior inside the document while saving all the runtime state
 *  		 in a user-specific filesystem location that ensures that runtime
 * 			 remains private for each user unless explicitly exported and likewise
 *  		 addresses the behavior of the system when the user uses undo/redo behavior.
 *  	     Simply, the document is all that supports undo/redo and the runtime merely
 * 	 		 captures all the operating statistics and state that correlates to the
 * 			 flow configuration in the document.
 *  DESIGN:  This document is saves as a package because I believe that it is going to
 * 			 be better to isolate configuration into categories, at least binary/json, but
 *  		 also multiple individual types to make them easier to find and parse.
 */
final class RRoutedDocument : ReferenceFileDocument {
	static var readableContentTypes: [UTType] { [.rroutedFlow] }
	
	// - the presence of this flag allows the UI to know when we're creating
	//   versus just opening the document so it can present a template selection
	//   modal for the user.
	let isNewDocument: Bool
	
	// - the engine saves all the document configuration and is intended to be referenced
	//   by SwiftUI throughout the app.  We *must* initialize it this way to omit concurrency
	//   checks that would occur in the non-isolated variants of init() below.
	let engine: RREngine
	
	// - the settings are the representation of locally persistent configuration
	//   in the app combining both global and document-specific information that
	//   should be saved outside the application.
	@MainActor var settings: RRUserSettings {
		if let ret = self._settings {
			return ret
		}
		let newSettings = RRUserSettings(with: engine, forNewDocument: isNewDocument)		// ...the engine ties some of the settings to the document.
		self._settings	= newSettings
		return newSettings
	}
	
	// - ensures that firewall changes across documents provide useful UI context for conflicts.
	@MainActor private static let firewallCoordinator: RRMultiFirewallCoordinator = .init()
	@MainActor lazy var firewallCoordinator: RRMultiFirewallCoordinator = {
		let ret = Self.firewallCoordinator
		ret.register(document: self)	// - must be only once per document when used
		return ret
	}()
		
	/*
	 *  Initialize a new document.
	 */
	init() {
		isNewDocument    = true
		self.engine	     = .init()
		self.engineToken = engine.objectWillChange.sink(receiveValue: { [weak self] (_) in
			self?.objectWillChange.send()
		})
		Task { await MainActor.run { self.coordinateEngineStartup() } }
		
		// NOTE:  This doesn't perform configuration because the SwiftUI DocumentGroup
		// 	 	  will create empty documents right before loading existing files, which
		// 		  I think is how it determines the class type to use for initializing with
		// 	 	  a ReadConfiguration.  Instead, we'll do this configuration elsewhere.
	}
	
	/*
	 *  Initialize from an existing document.
	 *  DESIGN: Remember that the 'Revert To' behavior in the document architecture will issue this
	 *  		call this initializer for each version it attempts to resurrect.
	 */
	init(configuration: ReadConfiguration) throws {
		isNewDocument    = false
		self.engine      = try RREngine.load(from: configuration.file)
		self.engineToken = engine.objectWillChange.sink(receiveValue: { [weak self] (_) in
			self?.objectWillChange.send()
		})
		self.configureExistingDocumentBehavior()
	}
	
	/*
	 *  Close the document, usually when its owning window is closed.
	 */
	func close() {
		// - it is important to explicitly perform these actions so that the processing
		//   halts quickly enough for a new one to be re-opened if desired without
		//   conflicting with the ports or related content.
		RRouted.log.info("Closing the document and stopping current processing.")
		Task { await self.engine.shutdown() }
	}
	
	/*
	 *  Generate a document snapshot.
	 */
	func snapshot(contentType: UTType) throws -> RREngineSnapshot {
		return try self.engine.snapshot()
	}
	
	/*
	 *  Write the document using a snapshot.
	 */
	func fileWrapper(snapshot: RREngineSnapshot, configuration: WriteConfiguration) throws -> FileWrapper {
		let ret = try snapshot.saveToFileWrapper(withExisting: configuration.existingFile)
		Task { await self.settings.synchronizeWithSavedDocument() }
		return ret
	}
	
	@MainActor private var _settings: RRUserSettings!
	private var engineToken: AnyCancellable?
}

/*
 *  Internal implementation.
 */
extension RRoutedDocument {
	/*
	 *  Perform post-read configuration.
	 */
	private func configureExistingDocumentBehavior() {
		Task {
			await MainActor.run {
				let _ = self.settings
				let _ = self.firewallCoordinator
				self.applyExistingFirewallSettings()
				self.coordinateEngineStartup()
			}
		}
	}
	
	/*
	 *  Apply the existing settings for the document if available.
	 */
	@MainActor
	private func applyExistingFirewallSettings() {
		guard self.settings.hasAuthorizedFirewall, let settings = self.settings.firewallSettings else { return }

		// - set this first so that if the firewall is disabled, *none* of the
		//   ports will come online as they are being configured.
		self.engine.firewall.isEnabled = settings.isFirewallEnabled
		
		// - apply all non-conflicting port settings
		for ps in settings.portSettings {
			guard self.firewallCoordinator.validateModifiedPortSettings(ps, in: self) == nil else { continue }
			guard let p = self.engine.firewall.ports.first(where: { $0.id == ps.id }) else { continue }
			p.applySettings(ps)
		}
	}
	
	/*
	 *  Start the engine after opening the document.
	 */
	@MainActor
	private func coordinateEngineStartup() {
		// - this is likely to require more work eventually to enable duplication and
		// 	 loading of snapshots.
		self.engine.start()
	}
}
