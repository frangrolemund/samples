//
//  RREngine+Snapshot.swift
//  RREngine
// 
//  Created on 10/24/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import Foundation

/// A point-in-time copy of the engine.
public final class RREngineSnapshot {
	private let config: RREngineConfig
	
	private struct DynamoSnapshot {
		let data: 	  Data
		let modified: Date
		init(_ data: Data, modified: Date) {
			self.data 	  = data
			self.modified = modified
		}
	}
	
	private let dynamoSnapshots: [RRIdentifier : DynamoSnapshot]
	
	/*
	 *  Initialize the object.
	 */
	init(config: RREngineConfig) throws {
		self.config = config
		
		// - iteratively encode the dynamos so that exceptions
		//   are thrown inline with this method.
		let je = JSONEncoder.standardRREncoder
		var dSnapshots: [RRIdentifier : DynamoSnapshot] = [:]
		for (k, v) in config.nodeSnapshots {
			let dData 	  = try v.encode(with: je)
			let dMod  	  = v.modifiedDate
			dSnapshots[k] = .init(dData, modified: dMod)
		}
		self.dynamoSnapshots = dSnapshots
	}
	
	/// Save the snapshot to a new/existing file wrapper.
	public func saveToFileWrapper(withExisting existingFile: FileWrapper? = nil) throws -> FileWrapper {
		log.info("Saving engine snapshot for repository \(self.config.repositoryId.uuidString, privacy: .public) to \(existingFile != nil ? "existing" : "new", privacy: .public) document.")
		do {
			return try _saveToFileWrapper(withExisting: existingFile)
		}
		catch {
			log.error("Failed to save snapshot data.  \(error.localizedDescription, privacy: .public)")
			throw error
		}
	}
	
	/*
	 *  Load a previously saved repository.
	 */
	static func loadFromFileWrapper(_ fileWrapper: FileWrapper) throws -> RREngineEnvironment {
		// ...these calls are most certainly concurrent, esp from time machine
		let lInst = RRIdentifier()
		log.debug("Beginning loading task \(lInst.briefId, privacy: .public) of repository document.")
		do {
			return try _loadFromFileWrapper(fileWrapper)
		}
		catch {
			log.error("Failed to load an engine repository in task \(lInst.briefId, privacy: .public) from a document.  \(error.localizedDescription, privacy: .public)")
			throw error
		}
	}
}

/*
 *  Internal implementation.
 */
extension RREngineSnapshot : RRLoggableCategory {
	static var logCategory: String? { "Engine" }
	
	private static let NodeDir: String = "nodes"
	
	/*
	 *  Save the snapshot to a new/existing file wrapper.
	 */
	private func _saveToFileWrapper(withExisting existingFile: FileWrapper? = nil) throws -> FileWrapper {
		let je = JSONEncoder.standardRREncoder

		// - always re-write the manifest because it includes the index
		let rm     	   				 = RRRepoManifest(from: self.config)
		let rmData 	   				 = try je.encode(rm)
		let fwManifest 				 = FileWrapper(regularFileWithContents: rmData)
		fwManifest.preferredFilename = RRRepoManifest.FileName
		
		// - build/update the dynamos sub-directory.
		let curDynamos = existingFile?.fileWrappers?[Self.NodeDir]
		let fwDynamos  = curDynamos?.isDirectory ?? false ? curDynamos : FileWrapper(directoryWithFileWrappers: [:])
		for (k, v) in self.dynamoSnapshots {
			let fName = "\(k.uuidString).json"
			
			// ...if there is an existing filewrapper the question is whether to update it or not.
			if let curD = fwDynamos?.fileWrappers?[fName] {
				if let updDt = curD.fileAttributes["NSFileModificationDate"] as? Date,
					updDt.timeIntervalSince(v.modified) >= 0 {
					continue
				}
				
				fwDynamos?.removeFileWrapper(curD)
			}

			// - add the file.
			fwDynamos?.addRegularFile(withContents: v.data, preferredFilename: fName)
		}
				
		// - save the content.
		if let existingFile = existingFile, existingFile.isDirectory {
			//
			// UPDATE EXISTING
			//
			if let oldMan = existingFile.fileWrappers?[RRRepoManifest.FileName] {
				existingFile.removeFileWrapper(oldMan)
			}
			existingFile.addFileWrapper(fwManifest)
			return existingFile
		}
		else {
			//
			// NEW FILE
			//
			var topFW: [String : FileWrapper] = [:]
			topFW[RRRepoManifest.FileName] 	  = fwManifest
			topFW[Self.NodeDir]			  	  = fwDynamos
			return FileWrapper(directoryWithFileWrappers: topFW)
		}
	}
	
	/*
	 *  Load the engine from the provided filewrapper.
	 */
	private static func _loadFromFileWrapper(_ fileWrapper: FileWrapper) throws -> RREngineEnvironment {
		// - load the non-dynnamo files first
		let jd       = JSONDecoder.standardRRDecoder
		let manifest = try decodedFile(in: fileWrapper, name: RRRepoManifest.FileName, of: RRRepoManifest.self, with: jd)
		var config 			   = RREngineConfig(id: manifest.id)
		for nId in manifest.nodeIndex {
			let (nData, fwData) = try file(in: fileWrapper, name: "\(Self.NodeDir)/\(nId.uuidString).json")
			config.saveNodeSnapshot(nData, modifiedDate: fwData.fileAttributes["NSFileModificationDate"] as? Date, forId: nId)
		}
		
		// - build the final environment.
		let ret = RREngineEnvironment(with: config)
		
		// - rebuild the encoded dynamos now that the environment exists.
		try ret.reloadNodeMapFromCache()
		
		return ret
	}
	
	/*
	 *  Find a sub-filewrapper.
	 */
	private static func fileWrapper(in filewrapper: FileWrapper, name: String) throws -> FileWrapper {
		let pathItems = name.split(separator: "/")
		if pathItems.isEmpty {
			throw RRError.repoResourceNotFound(name)
		}
		
		var curFW = filewrapper
		
		for pi in pathItems {
			if curFW.isDirectory, let subFW = curFW.fileWrappers?[String(pi)] {
				curFW = subFW
			}
			else {
				throw RRError.repoResourceNotFound(name)
			}
		}
		
		guard curFW.isRegularFile else {
			throw RRError.repoResourceInvalid(name, "The resource is not a valid, regular file.")
		}
		
		return curFW
	}
	
	/*
	 *  Find a file in the file wrapper.
	 */
	private static func file(in fileWrapper: FileWrapper, name: String) throws -> (Data, FileWrapper) {
		let curFW = try self.fileWrapper(in: fileWrapper, name: name)
		guard let fileData = curFW.regularFileContents  else {
			throw RRError.repoResourceInvalid(name, "The resource is not a valid, regular file.")
		}
		
		return (fileData, curFW)
	}
	
	/*
	 *  Find and decode a file in the file wrapper.
	 */
	private static func decodedFile<T: Decodable>(in fileWrapper: FileWrapper, name: String, of type: T.Type, with decoder: JSONDecoder) throws -> T {
		let (fData, _) = try file(in: fileWrapper, name: name)
		do {
			return try decoder.decode(type, from: fData)
		}
		catch {
			throw RRError.repoResourceInvalid(name, error.localizedDescription)
		}
	}
}

/*
 *  The manifest describes the overall state of the repository.
 */
fileprivate struct RRRepoManifest : Codable {
	static let FileName: String = "manifest.json"
	
	var id: RRIdentifier
	var nodeIndex: [RRIdentifier]
	
	/*
	 *  Initialize the object.
	 */
	init(from config: RREngineConfig) {
		self.id 		 = config.repositoryId
		self.nodeIndex = Array(config.nodeIds)
	}
	
	/*
	 *  Initialize the object.
	 */
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.id 		 = try container.decode(RRIdentifier.self, forKey: .id)
		self.nodeIndex = try container.decode([RRIdentifier].self, forKey: .nodeIndex)
	}
	
	/*
	 *  Encode the object.
	 */
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.id, forKey: .id)
		try container.encode(self.nodeIndex, forKey: .nodeIndex)
	}
	
	private enum CodingKeys : String, CodingKey {
		case id 		= "repoId"
		case nodeIndex	= "nodeIndex"
	}
}
