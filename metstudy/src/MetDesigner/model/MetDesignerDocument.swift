//
//  MetDesignerDocument.swift
//  MetDesigner
// 
//  Created on 1/13/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import UniformTypeIdentifiers
import MetModel

/*
 *  The MetDesigner document persists the following data:
 *  - the parsed MetObjects.csv index that is used to search for interesting content.
 *  - the exhibits and tours that have been built from the index + the REST API.
 *
 *  As the document is a common fixture, it is also used to propagate shared temporary
 *  state between views like selection and cached resources.
 */
class MetDesignerDocument: ReferenceFileDocument {
	typealias Snapshot = MDDocumentSnapshot
	
	// - the types that are supported by this document.
	static var readableContentTypes: [UTType] { [.metDesignerType] }
	
	// - the local, document-scoped state for the user interface.
	let userState: MDUserState
	
	/*
	 *  Initialize the object.
	 */
	init() {
		let snapshot   = MDDocumentSnapshot()
		self.persisted = snapshot
		self.userState = .init(documentId: snapshot.id, forNewDocument: true)
	}
	
	/*
	 *  Initialize the object.
	 */
	required init(configuration: ReadConfiguration) throws {
		guard configuration.contentType == .metDesignerType else {
			throw MDError.brokenInvariant("Unexpected request to read snapshot type of \(configuration.contentType.identifier).")
		}
		let snapshot = try Self.loadDocumentSnapshot(from: configuration.file)
		self.persisted = snapshot
		self.userState = .init(documentId: snapshot.id, forNewDocument: false)
		self.setCacheDirectory()
	}
	
	/*
	 *  Take a snapshot of the document state.
	 */
	func snapshot(contentType: UTType) throws -> Snapshot {
		guard contentType == .metDesignerType else {
			throw MDError.brokenInvariant("Unexpected request to generate snapshot type of \(contentType.identifier).")
		}
		return self.persisted
	}
	
	/*
	 *  Save the document.
	 */
	func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
		let ret = try self.saveDocumentSnapshot(snapshot: snapshot, configuration: configuration)
		self.userState.enableFilePersistence()
		return ret
	}
	
	@Published private var persisted: MDDocumentSnapshot
}

/*
 *  Accessors
 */
extension MetDesignerDocument {
	// - determine if we have a valid index.
	var isIndexed: Bool { objectIndex != nil }
	
	// - return the configured index.
	var objectIndex: MMObjectIndex? { self.persisted.objectIndex }
	
	/*
	 *  Set the object index.
	 */
	func saveObjectIndex(_ newIndex: MMObjectIndex?, undoManager: UndoManager? = nil) {
		let priorIndex 			   = self.persisted.objectIndex
		self.persisted.objectIndex = newIndex
		self.setCacheDirectory()
		undoManager?.setActionName("Import MetObjects")
		undoManager?.registerUndo(withTarget: self, handler: { doc in
			doc.saveObjectIndex(priorIndex, undoManager: undoManager)
		})
	}
}

/*
 *  Utilities.
 */
extension UTType {
	static var metDesignerType: UTType {
		UTType(exportedAs: "com.realproven.metdesigner")
	}
}

/*
 *  Stores the persistent state of the MetDesigner document.
 *  DESIGN:  The intention is that all of the document state is stored in this
 *  		 value type which should make it trivial to quickly copy it during
 * 			 the snapshotting process.
 */
struct MDDocumentSnapshot : Identifiable {
	/*
	 *  PERSISTENT data in the document.
	 */
	let manifest: Manifest
	fileprivate (set) var objectIndex: MMObjectIndex?
		
	var id: MDUniqueIdentifier { manifest.id }
	
	/*
	 *  Initialize the object.
	 */
	init(with manifest: Manifest? = nil) {
		self.manifest = manifest ?? Manifest(id: UUID(), created: .init())
	}
	
	// - top level descriptor of the document contents.
	struct Manifest : Codable {
		let id: MDUniqueIdentifier
		let created: Date
	}
}

/*
 *  Internal implementation.
 */
extension MetDesignerDocument {
	private static var Manifest: String		= "manifest.json"
	private static var ObjectIndex: String  = "object-index.json"
	
	/*
	 *  Write the document to disk.
	 */
	private func saveDocumentSnapshot(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
		let ret = configuration.existingFile ?? FileWrapper(directoryWithFileWrappers: [:])
		
		// - the identifier
		try ret.writeChildEncoded(snapshot.manifest, asName: Self.Manifest)
		
		// - the index, which may not have been set yet.
		if let curIdx = ret.fileWrappers?[Self.ObjectIndex] {
			/// ...normally the index is not overwritten, but if it is discarded then
			///    remove the item.
			if snapshot.objectIndex == nil {
				ret.removeFileWrapper(curIdx)
			}
		}
		else if let newIdx = snapshot.objectIndex {
			try ret.writeChildEncoded(newIdx, asName: Self.ObjectIndex, isPretty: false)
		}
				
		return ret
	}
	
	/*
	 *  Load the document from a file wrapper.
	 */
	private static func loadDocumentSnapshot(from file: FileWrapper) throws -> Snapshot {
		// - the manifest
		guard let manifest = try file.readChildEncoded(named: Self.Manifest, asType: Snapshot.Manifest.self) else {
			MDLog.alert("The manifest was not found in the provided document.")
			throw MDError.invalidDocument
		}
		var ret = MDDocumentSnapshot(with: manifest)
		
		// - the object index if it exists.
		ret.objectIndex = try file.readChildEncoded(named: Self.ObjectIndex, asType: MMObjectIndex.self)
		
		return ret
	}
	
	/*
	 *  Assign the local cache directory for the document/index.
	 */
	private func setCacheDirectory() {
		guard let oIndex = persisted.objectIndex else { return }
		do {
			let cURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			try oIndex.setCacheRootDirectory(url: cURL)
		}
		catch {
			MDLog.error("The cache root for the index could not be assigned, reverting to uncached.  \(error.localizedDescription)")
		}
	}
}

/*
 *  Utilities
 */
fileprivate extension FileWrapper {
	/*
	 *  Add a child wrapper using the JSON encoding of the content.
	 */
	func writeChildEncoded<T: Encodable>(_ child: T, asName named: String, isPretty: Bool = true) throws {
		do {
			let data 				  = try child.standardDesignerJSONEncoding(isPretty: isPretty)
			let fwChild 			  = FileWrapper(regularFileWithContents: data)
			fwChild.preferredFilename = named
			if let oldFW = self.fileWrappers?[named] {
				self.removeFileWrapper(oldFW)
			}
			self.addFileWrapper(fwChild)
		}
		catch {
			MDLog.error("Failed to encode the document item '\(named)'.  \(error.localizedDescription)")
			throw error
		}
	}
	
	/*
	 *  Read a JSON encoded child wrapper item.
	 */
	func readChildEncoded<T: Decodable>(named: String, asType type: T.Type) throws -> T? {
		guard let childFW = self.fileWrappers?[named] else { return nil }
		guard let data = childFW.regularFileContents else {
			MDLog.alert("There was unexpected missing file data for the document item '\(named)'.")
			throw MDError.invalidDocument
		}
		
		do {
			return try type.standardDesignerJSONDecoding(from: data)
		}
		catch {
			MDLog.error("Failed to decode the document item '\(named)'.  \(error.localizedDescription)")
			throw error
		}
	}
}
