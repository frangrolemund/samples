//
//  RRUserSettings.swift
//  RRouted
// 
//  Created on 9/30/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation
import Combine
import RREngine

/*
 *  Persistent, local configuration settings outside the document.
 *  DESIGN:  There are two kinds of settings stored here which
 *  		 are the (1) document-specific settings and the (2)
 * 			 global settings that span all documents.
 *  DESIGN:  Internally, the principle is that anything that
 *  		 we save is in one of these two categories and the
 *  		 results are always cached in this object.  The
 *  		 implementation simply encodes (via JSON) these
 * 			 items in the local system.
 */
@MainActor
final class RRUserSettings : ObservableObject, RRUIPresentable {
	/*
	 *  Build a preview-capable entity.
	 */
	static func preview(ofPreviewType previewType: Void?) -> RRUserSettings {
		return RRUserSettings(with: .init())
	}
	
	/*
	 *  Initialize the settings.
	 */
	init(with engine: RREngine, forNewDocument newDocument: Bool = false) {
		self.repoId 	         = engine.repositoryId
		self.linkedToNewDocument = newDocument
		self.loadOrCreateSettings()

		// - any change to global settings will notify watchers of this object.
		self.globalToken = Self._gs.sink(receiveValue: { [weak self] (_) in
			self?.objectWillChange.send()
		})
	}
	
	private let repoId: RRIdentifier
	@Published private var docSettings: RRDocumentUserSettings! {
		didSet {
			guard oldValue != nil else { return }
			self.saveDocumentSettings()
		}
	}
	
	/*
	 *  The document calls this method to confirm it was persisted.
	 */
	func synchronizeWithSavedDocument() {
		self.linkedToNewDocument = false
	}
	
	/*
	 *  Destroy the object.
	 */
	deinit {
		globalToken?.cancel()
		
		// - if a new document was never saved, there is no need to retain
		//   pending settings that will never be used.
		if self.linkedToNewDocument {
			self.deleteUnusedSettings()
		}		
	}
	
	private var globalToken: AnyCancellable?
	private var linkedToNewDocument: Bool
	
	private static var globalSettings: RRGlobalUserSettings {
		get { _gs.value }
		set {
			_gs.value = newValue
			Self.saveSettingsFile(newValue, to: Self.GlobalFileName)
		}
	}
	
	// ...use this approach so that the individual documment user settings can subscribe to it.
	private static let _gs: CurrentValueSubject<RRGlobalUserSettings, Never> = .init(RRUserSettings.loadSettingsFile(from: RRUserSettings.GlobalFileName) ?? RRGlobalUserSettings())
}

/*
 *  Internal.
 */
extension RRUserSettings {
	static fileprivate let GlobalFileName: String = "global"
	
	/*
	 *  Load user settings from disk, creating them if they don't yet exist.
	 */
	private func loadOrCreateSettings() {
		let ds: RRDocumentUserSettings? = Self.loadSettingsFile(from: repoId.uuidString)
		self.docSettings    		    = ds ?? .init()
	}
	
	/*
	 *  Attempt to load a settings file.
	 */
	static private func loadSettingsFile<T: Codable>(from name: String) -> T? {
		let fName = settingsURL(for: name)
		if let d = try? Data(contentsOf: fName) {
			return try? T.rrDecoding(from: d)
		}
		return nil
	}
	
	/*
	 *  Delete settings that are not connected to a working document.
	 */
	nonisolated private func deleteUnusedSettings() {
		let sURL = Self.settingsURL(for: self.repoId.uuidString)
		guard FileManager.default.fileExists(atPath: sURL.path(percentEncoded: false)) else { return }
		do {
			try FileManager.default.removeItem(at: sURL)
		}
		catch {
			RRouted.log.error("Failed to remove the unused settings file at \(sURL.standardizedFileURL, privacy: .public).  \(error.localizedDescription, privacy: .public)")
		}
	}
	
	/*
	 *  Generate the file name.
	 */
	nonisolated static private func settingsURL(for name: String) -> URL {
		var targetURL = RRouted.directories.setttingsDirectory
		targetURL.append(path: "\(name).json")
		return targetURL
	}
		
	/*
	 *  Save document settings.
	 */
	private func saveDocumentSettings() {
		guard let ds = self.docSettings else { return }
		Self.saveSettingsFile(ds, to: repoId.uuidString)
	}
	
	/*
	 *  Savae the settings file to the target.
	 */
	nonisolated static private func saveSettingsFile<T: Codable>(_ data: T, to name: String) {
		Task(priority: .background) {
			let target = self.settingsURL(for: name)
			do {
				let encoded = try data.rrEncoding()
				try encoded.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
			}
			catch {
				RRouted.log.error("Failed to save the settings file \(name, privacy: .public).  \(error.localizedDescription, privacy: .public)")
			}
		}
	}
}

/*
 *  Accessors
 *  DESIGN: Create wrappers for all settings to hide the structural details.
 */
extension RRUserSettings {
	var authorIdentifier: RRIdentifier { Self.globalSettings.authorIdentifier }
	
	var hasAuthorizedFirewall: Bool {
		get { docSettings.hasAuthorizedFirewall ?? false }
		set { docSettings.hasAuthorizedFirewall = newValue }
	}
	
	var firewallSettings: RRFirewallSettings? {
		get { docSettings.firewallSettings }
		set { docSettings.firewallSettings = newValue }
	}
	
	var hasSeenFirewallConfiguration: Bool {
		get { Self.globalSettings.hasSeenFirewallConfiguration ?? false }
		set { Self.globalSettings.hasSeenFirewallConfiguration = newValue }
	}
}
