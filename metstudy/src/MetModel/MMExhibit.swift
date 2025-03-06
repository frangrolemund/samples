//
//  MMExhibit.swift
//  MetModel
// 
//  Created on 2/26/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation

/// Defines a single piece of art history from the Met Art museum that
/// has been curated specially for display in custom client viewers.  It
/// represents both the official record of attributes as well as customized,
/// edited ones for the purpose of display in client viewing applications.
@Observable 
public class MMExhibit : MMExhibitIdentifiable, Codable, Identifiable, Equatable {
	/// Test for equivalence.
	public static func == (lhs: MMExhibit, rhs: MMExhibit) -> Bool { lhs.id == rhs.id }
	
	/// The unique identifier of the exhibit instance.  Notice that this is different
	/// than the MetArt objectID because a single exhibit reference (MMExhibitRef) can
	/// generate multiple exhibits, each one with different customizations.
	public let id: String
	
	/*
	 *  Initialize the exhibit.
	 */
	init(object: MMObject, owner: MMExhibitCacheOwnable? = nil) {
		self.id  		 = UUID().uuidString
		self.obj 		 = object
		self.cacheOwner  = owner
		
		// - start loading the associated resources in full sized form since we're
		//   using this for design.  The cache owner should be consolidating these
		//   requests intelligently to minimize discards and needless re-queries.
		guard let _ = owner, (self.primaryImageURL != nil || !self.additionalImageURLs.isEmpty) else { return }
		let eResources = ((self.primaryImageURL != nil) ? [self.primaryImageURL!] : []) + self.additionalImageURLs
		self.summaryTask = Task { [weak self] () in
			await withTaskGroup(of: Void.self) { group in
				for img in eResources {
					group.addTask { [weak self] () in
						// ...route through the cache owner so that they get saved.
						let _ = await self?.cacheOwner?.queryMetArtFile(atURL: img)
					}
				}
			}
			self?.summaryTask = nil
		}
	}
	
	/// Decode the exhibit from an archive.
	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.id 	  = try container.decode(String.self, forKey: .id)
		self.obj	  = try container.decode(MMObject.self, forKey: .object)
	}
	
	/// Encode the exhbit to an archive.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.id, forKey: .id)
		try container.encode(self.obj, forKey: .object)
	}
	
	// - internal
	private enum CodingKeys : CodingKey {
		case id
		case object
	}
	
	let obj: MMObject
	weak var cacheOwner: MMExhibitCacheOwnable?
	private var summaryTask: Task<Void, Never>?
	
	// ..the exhibits cache images in RAM when accessed since their
	//   retrieval and conversion is a non-trivial process that shouldn't
	//   be passed onto the UI.
	private var _primaryImage: MMImageRef?		 = nil
	private var _primaryImageSmall: MMImageRef?	 = nil
	private var _additionalImages: [MMImageRef]? = nil
}

/*
 *  A reference to a cache-providing entity after initial creation, allowing
 *  for high performance access of related assets (images) during design, while
 *  reverting to explicit query for app scenarios.
 *
 */
protocol MMExhibitCacheOwnable : AnyObject {
	func queryMetArtFile(atURL url: URL) async -> MMNetworkClient.MetArtFileResult
}

/*
 *  Accessors.
 */
extension MMExhibit {
	///  Retrieve the primary image.
	public var primaryImage: MMImageRef? {
		get async {
			if self._primaryImage == nil, let iData = await queryImageData(for: self.primaryImageURL) {
				self._primaryImage = iData
			}
			return self._primaryImage
		}
	}
	
	///  Retrieve a small version of the primary image.
	public var primaryImageSmall: MMImageRef? {
		get async {
			if self._primaryImageSmall == nil, let iData = await queryImageData(for: self.primaryImageSmallURL) {
				self._primaryImageSmall = iData
			}
			return self._primaryImageSmall
		}
	}
	
	/// Retrieve the supplemental images for the exhibit.
	public var additionalImages: [MMImageRef] {
		get async {
			if let aImgs = self._additionalImages { return aImgs }
			var result: [MMImageRef] = []
			let urls = self.additionalImageURLs
			if !urls.isEmpty {
				result = await withTaskGroup(of: Optional<MMImageRef>.self, returning: [MMImageRef].self, body: { tGroup in
					urls.forEach { url in
						tGroup.addTask { [weak self] () in
							return await self?.queryImageData(for: url)
						}
					}
					var imgs: [MMImageRef] = []
					for await val in tGroup.compactMap({$0}) {
						imgs.append(val)
					}
					return imgs
				})
			}
			self._additionalImages = result
			return result
		}
	}
}

/*
 *  Internal implementation.
 */
extension MMExhibit {
	/*
	 *  Wait for the exhibit to cache resources used for design.
	 */
	func waitForCachingOfAssociatedResources() async {
		await summaryTask?.value
	}
	
	/*
	 *  Retrieve data from a remote file.
	 */
	private func queryFileData(for url: URL?) async -> Data? {
		guard let url = url else { return nil }
		
		// ...try to go through the cache if available.
		let result: MMNetworkClient.MetArtFileResult
		if let cOwner = cacheOwner {
			result = await cOwner.queryMetArtFile(atURL: url)
		}
		else {
			result = await MMNetworkClient.shared.queryMetArtFile(atURL: url)
		}
		
		switch result {
		case .success(let ret):
			return ret
			
		case .failure(let error):
			MMLog.error("Failed to query for MetArt file data at \(url.absoluteString).  \(error.localizedDescription)")
			return nil
		}
	}
	
	/*
	 *  Retrieve image data from a remote file.
	 */
	private func queryImageData(for url: URL?) async -> MMImageRef? {
		guard let fd = await queryFileData(for: url) else { return nil }
		return await MMImageRef.fromData(fd, withFileData: true)
	}
}
