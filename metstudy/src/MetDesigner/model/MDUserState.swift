//
//  MDUserState.swift
//  MetDesigner
// 
//  Created on 2/1/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import AppKit
import MetModel

/*
 *  The user state is a document-scoped representation of the user-specific
 *  state (both transient and persistent).
 *  DESIGN:  Each attribute should be evaluated as (1) either transient or 
 * 			 persistent and (2) whether it is published to force UI updates.
 * 			 Not every scenario requires UI invalidations.
 *  DESIGN:  The built-in features in SwiftUI for user state weren't ideal
 * 			 for what I wanted to achieve with the document windows so I
 * 			 opted for a more manual approach.  Also, UserDefaults appears
 * 			 to be something that Apple is discouraging more with its
 *  		 new privacy requirements, etc. which also made a case for
 * 			 something custom.
 */
@Observable 
final class MDUserState {
	/*
	 *  Initialze the state.
	 *  DESIGN:  The SwiftUI document architecture creates bogus new documents
	 *   		 all the time, even during loading of other documents which I
	 * 			 suspect is used for some sort of introspection purpose.  For this
	 * 			 reason, this class only tries to save the user state when
	 * 			 something has been changed, but not before.  That lets the unused
	 * 			 ones exist without creating phantom state on disk.
	 */
	init(documentId: MDUniqueIdentifier, forNewDocument newDocument: Bool) {
		self.documentId      = documentId
		let stateFileURL     = Self.stateFileURL(forId: documentId)
		self.stateFileURL    = stateFileURL
		self.canSave		 = !newDocument
		self.directoryExists = false
		
		if !newDocument, let ps = Self.readPersistentState(fromFile: stateFileURL) {
			self.directoryExists = true
			self.persistentState = ps
			self._filterContext  = self.readFilterContext()
			self._selectionState = ps.selectionState
		}
		else {
			// ... new files and fallback for error.
			self.persistentState = .init()
		}
	}
	
	/*
	 *  The user state won't be saved until the document is for the first time
	 *  which keeps the crud to a minimum
	 */
	func enableFilePersistence() {
		guard !canSave else { return }
		canSave = true
		self.saveAll()
	}
	
	private let documentId: MDUniqueIdentifier
	private var stateFileURL: URL
	private var directoryExists: Bool
	private var persistentState: PersistentState {
		didSet {
			guard persistentState != oldValue else { return }
			savePersistentState()
		}
	}
	private var canSave: Bool
	
	private var dtState: DelayedTask?
	
	// ...publishes UI changes.
	private var _filterContext: MMFilterContext?
	private var dtFilter: DelayedTask?	
	private var _selectionState: MDSelectionState?
}

/*
 *  Accessors
 */
extension MDUserState {
	var windowSize: CGSize {
		get { self.persistentState.windowSize }
		set { self.persistentState.windowSize = newValue }
	}
	
	var navigatorWidth: CGFloat? {
		get { self.persistentState.navigatorWidth }
		set { self.persistentState.navigatorWidth = newValue }
	}
	
	var editorWidth: CGFloat? {
		get { self.persistentState.editorWidth }
		set { self.persistentState.editorWidth = newValue }
	}

	var inspectorWidth: CGFloat? {
		get { self.persistentState.inspectorWidth }
		set { self.persistentState.inspectorWidth = newValue }
	}
	
	var indexSearchHeight: CGFloat? {
		get { self.persistentState.indexSearchHeight }
		set { self.persistentState.indexSearchHeight = newValue }
	}
	
	var tourEditorHeight: CGFloat? {
		get { self.persistentState.tourEditorHeight }
		set { self.persistentState.tourEditorHeight = newValue }
	}
	
	var filterContext: MMFilterContext? {
		get { self._filterContext }
		set { 
			self._filterContext = newValue
			self.saveFilterContext()
		}
	}
	
	var selectionState: MDSelectionState? {
		get { self._selectionState }
		set {
			self._selectionState 				= newValue
			self.persistentState.selectionState = newValue
		}
	}
}

/*
 *  Internal
 */
extension MDUserState {
	/*
	 *  Retains state that is persisted to disk.
	 */
	private struct PersistentState : Codable, Equatable {
		// - the dimensions of the app window.
		var windowSize: CGSize
		
		// - relevant dimensions of splitter positions
		var navigatorWidth: CGFloat?
		var editorWidth: CGFloat?
		var inspectorWidth: CGFloat?
		var indexSearchHeight: CGFloat?
		var tourEditorHeight: CGFloat?
		var selectionState: MDSelectionState?
		
		/*
		 *  Initialize the state from defaults.
		 */
		init() {
			let screenFrame = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 1440, height: 900)
			let width 		= (screenFrame.width * 0.4).rounded()
			let height		= min((width / (16.0 / 9.0)).rounded(), (screenFrame.height * 0.7).rounded())
			self.windowSize = .init(width: width, height: height)
		}
	}
	
	/*
	 *  The local directory where document state is stored.
	 */
	private static func stateDirectoryURL(forId documentId: MDUniqueIdentifier) -> URL {
		let asdURL: URL
		if let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			asdURL = u
		}
		else {
			MDLog.alert("Failed to retrieve the application support directory.")
			asdURL = .init(filePath: "/tmp", directoryHint: .isDirectory)
		}
		
		return asdURL.appending(path: "MetDesigner.UserState").appending(path: documentId.uuidString)
	}
	
	/*
	 *  Return the state directory location.
	 */
	private func stateDirectoryURL() -> URL {
		self.stateFileURL.deletingLastPathComponent()
	}
	
	/*
	 *  The filename for user state attributes.
	 */
	private static func stateFileURL(forId documentId: MDUniqueIdentifier) -> URL {
		return stateDirectoryURL(forId: documentId).appending(component: "user-state.json")
	}
	
	/*
	 *  Attempt to load the persistent state for the provided document.
	 */
	private static func readPersistentState(fromFile fileURL: URL) -> PersistentState? {
		guard let data = try? Data(contentsOf: fileURL) else {
			let path = fileURL.path(percentEncoded: true)
			if FileManager.default.fileExists(atPath: path) {
				MDLog.error("The user state at \(path) could not be loaded, forcing recreation.")
			}
			return nil
		}
		
		do {
			return try PersistentState.standardDesignerJSONDecoding(from: data)
		}
		catch {
			assert(false, "Unexpected user state decoding failure.")
			MDLog.error("The user state could not be decoded from disk. \(error.localizedDescription)")
			return nil
		}
	}
	
	/*
	 *  Save all content in the user state.
	 */
	private func saveAll() {
		savePersistentState()
		saveFilterContext()
	}
	
	/*
	 *  Save persistent state to disk.
	 */
	private func savePersistentState() {
		guard self.canSave else { return }
		
		let fileURL = self.stateFileURL
		let tmp 	= self.persistentState
		
		// ...create the directory on first save to avoid clutter.
		if !directoryExists {
			let dirOnly = fileURL.deletingLastPathComponent()
			MDLog.info("Initializing a document user state directory at \(dirOnly.path(percentEncoded: false)).")
			if !FileManager.default.fileExists(atPath: dirOnly.path(percentEncoded: false), isDirectory: nil) {
				do {
					try FileManager.default.createDirectory(at: dirOnly, withIntermediateDirectories: true)
					self.directoryExists = true
				}
				catch {
					MDLog.alert("Failed to create the user state directory at '\(dirOnly.path(percentEncoded: false))'.  \(error.localizedDescription)")
				}
			}
		}
		
		self.delayedSaveTask(task: &self.dtState, value: tmp, asDesc: "user state", toURL: fileURL)
	}
	
	/*
	 *  Perform a save operation.
	 */
	typealias DelayedTask = Task<Void, Never>
	private func delayedSaveTask<C: Codable>(task: inout DelayedTask?, value: C?, asDesc desc: String, toURL url: URL) {
		// - don't allow saving until we're ready
		guard canSave else { return }
		
		// - delay the saving of the state for a few momements to let things calm down
		//   if we're getting a lot of updates.
		task?.cancel()
		task = Task(priority: .background) {
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			
			do {
				// ...a nil value indicates it should be deleted.
				guard let value = value else {
					try FileManager.default.removeItem(at: url)
					return
				}
				
				let data = try value.standardDesignerJSONEncoding()
				await MainActor.run {
					do {
						try data.write(to: url, options: .atomic)
					}
					catch {
						MDLog.error("Failed to save the \(desc) at '\(url.path(percentEncoded: false))'.  \(error.localizedDescription)")
					}
				}
			}
			catch {
				MDLog.error("Failed to encode the \(desc).  \(error.localizedDescription)")
			}
		}
	}
	
	private var filterContextURL: URL { stateDirectoryURL().appendingPathComponent("filter-context.json") }
	
	/*
	 *  Read the filtering context as user state.
	 *  NOTE: This context can be non-trivial in size so we're saving it separately.
	 */
	private func readFilterContext() -> MMFilterContext? {
		do {
			guard let d = try? Data(contentsOf: self.filterContextURL) else {
				return nil
			}
			return try MMFilterContext.standardDesignerJSONDecoding(from: d)
		}
		catch {
			MDLog.error("Failed to read the filter context, defaulting to empty state.  \(error.localizedDescription)")
			return nil
		}
	}
	
	/*
	 *  Save the filter context.
	 */
	private func saveFilterContext() {
		self.delayedSaveTask(task: &self.dtFilter,
							 value: self.filterContext,
							 asDesc: "filter context",
							 toURL: self.filterContextURL)
	}
}
