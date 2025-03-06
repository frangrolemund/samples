//
//  MMObjectIndex.swift
//  MetModel
// 
//  Created on 1/17/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif

///  A decoded representation of the [Metropolitan Museum Art Open
///  Access CSV](https://github.com/metmuseum/openaccess) file that
///  includes indexing and associations for all the Met Art museum
///  pieces.
///
///  This index is very large on disk, so it is intentionally a reference
///  type to avoid unnecessary copies.
public class MMObjectIndex : Codable, Identifiable {
	///  The unique identifier for this index.
	public let id: UUID
	
	/*
	 *  Read the index from the provided file URL.
	 */
	static func read(from url: URL, receivingStatus: StatusCallback? = nil) async throws -> MMObjectIndex {
		return try await Task(priority: .background) {
			let ret = try MMObjectIndex(with: url)
			do {
				// - parse the file, communicating status as needed.
				try await ret.parseAndIndexFile { status in
					guard let receivingStatus = receivingStatus else { return }
					
					// ...make sure this is sent to the main thread.
					Task.detached {	await MainActor.run { receivingStatus(status) }	}
				}
				
				// - the act of parsing the file consumes a lot of string memory
				//   that isn't easily returned to the process, but by encoding
				//	 and decoding it, we can release what I'm assuming is a more
				//   fragmented heap in favor of better aligned string data.
				Task.detached {	await MainActor.run { receivingStatus?(.optimizing) } }
				let jData = try ret.standardMMJSONEncoding()
				return try MMObjectIndex.standardMMJSONDecoding(of: jData)
			}
			catch {
				MMLog.error("\(error.localizedDescription, privacy: .public)")
				throw error
			}
		}.result.get()
	}
	
	/// Provides updates to model consumers of the progress indexing.
	public enum IndexingStatus {
		case started(totalCount: Int)
		case progress(row: Int, totalCount: Int)
		case completed(skipped: Int, indexed: Int, indexingRate: Double)
		case optimizing
	}
	
	/// Receives updates of the indexing progress.
	public typealias StatusCallback = (_ status: IndexingStatus) -> Void
	
	/*
	 *  Allocate an empty index.
	 */
	static var emptyIndex: MMObjectIndex { .init() }
	init() {
		self.id 		= UUID()
		self.objectList = []
		self.objectMap	= [:]
	}
	
	/*
	 *  Initialize the object.
	 */
	convenience init(with url: URL) throws {
		guard let fs = fopen(url.path(), "r") else {
			throw MMError.invalidFile
		}
		self.init()
		self.fStream = fs
	}
		
	/// Decode the object.
	public required init(from decoder: Decoder) throws {
		let container 		= try decoder.container(keyedBy: CodingKeys.self)
		self.id				= try container.decode(UUID.self, forKey: .indexId)
		self.fStream 		= nil
		self.objectList		= []
		self.objectMap		= [:]
		let objs 			= try container.decode([MMExhibitRef].self, forKey: .objectList)
		for oneObj in objs {
			self.addReferenceToIndex(oneObj)
		}		
	}
	
	/// Encode the object.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.id, forKey: .indexId)
		try container.encode(self.objectList, forKey: .objectList)
	}
	
	/// Assign a local directory for caching purposes to the index.  The cache directory will not
	/// be saved with the index when it is encoded and must be assigned explicitly for each
	/// index.
	public func setCacheRootDirectory(url: URL) throws {
		var isDir: ObjCBool = false
		guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDir), isDir.boolValue else {
			throw MMError.invalidFile
		}
		let eCacheURL	   = url.appending(path: "MMObjectIndex").appending(path: "exhibits")
		let eCacheFilesURL = url.appending(path: "MMObjectIndex").appending(path: "files")
		try FileManager.default.createDirectory(at: eCacheURL, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: eCacheFilesURL, withIntermediateDirectories: true)
		self.exhibitCacheURL 	 = eCacheURL
		self.exhibitFileCacheURL = eCacheFilesURL
	}
	
	/*
	 *  Destructor
	 */
	deinit {
		guard self.fStream != nil else { return }
		fclose(self.fStream)
	}
	
	// - codable keys.
	private enum CodingKeys : String, CodingKey {
		case indexId			= "id"
		case objectList			= "objectList"
	}
	
	// - internal
	private var fStream: UnsafeMutablePointer<FILE>?		// - only for creation
	private var lineCount: Int?								// - only for creation
	private var headerMap: [IndexedColumn : Int]?			// - only for creation
	private var columnCount: Int = 0						// - only for creation
	private var columnCache: [String] = []					// - only for creation
	
	var objectList: [ MMExhibitRef ]
	var objectMap: [ UInt : MMExhibitRef]
	private var exhibitCacheURL: URL?
	private var exhibitFileCacheURL: URL?
}

/*
 *  Accessors
 */
extension MMObjectIndex : Sequence {
	/// The number of indexed objects.
	public var count: Int { objectMap.count }
	
	/// Return an object by offset.
	public subscript(index: Int) -> MMExhibitRef? {
		guard index < objectList.count else { return nil }
		return objectList[index]
	}
	
	/// Returns an iterator over the elements of the sequence.
	public func makeIterator() -> MMObjectIndexIterator {
		return .init(index: self)
	}
	
	/// Return an object by ObjectID
	public func object(byID objectID: UInt) -> MMExhibitRef? {
		return objectMap[objectID]
	}
	
	/// A type that provides Sequence-compatible iteration over an index.
	public struct MMObjectIndexIterator : IteratorProtocol {
		/*
		 *  Initialize the object.
		 */
		init(index: MMObjectIndex) {
			self.index  = index
			self.offset = 0
		}
		
		/*
		 *  Get the next item in the sequence.
		 */
		mutating public func next() -> MMExhibitRef? {
			guard offset < index.objectList.count else { return nil }
			let ret = index.objectList[offset]
			offset += 1
			return ret
		}
		
		// - internal
		private let index: MMObjectIndex
		private var offset: Int
	}
	
	///  Return an exhibit instance from its reference.
	public func exhibit(from exhibitRef: MMExhibitRef) async -> Result<MMExhibit, Error> {		
		do {
			let ret: MMExhibit
			if let eCached = exhibitFromCache(eRef: exhibitRef) {
				ret = eCached
			}
			else {
				let obj = try await MMNetworkClient.shared.queryMetArtObject(identifiedBy: exhibitRef.objectID).get()
				ret 	= MMExhibit(object: obj, owner: self)
				saveExhibitToCache(exhibit: ret)
			}
			await ret.waitForCachingOfAssociatedResources()
			return .success(ret)
		}
		catch {
			MMLog.error("Failed to query the exhibit \(exhibitRef.objectID, privacy: .public).  \(error.localizedDescription, privacy: .public)")
			return .failure(error)
		}
	}
}

/*
 *  Filtering
 */
extension MMObjectIndex {
	// ...convenience initializer.
	private var fullIndex: MMExhibitCollection { return .init(context: .init(indexId: self.id, criteria: nil, _offsets: nil), objectIndex: self) }
	
	///  Filter the context using a previously generated context.  Pass `nil` to return an unfiltered collection.
	public func filtered(using context: MMFilterContext?) async throws -> MMExhibitCollection {
		guard let context = context else {
			return self.fullIndex
		}
		
		guard context.indexId == self.id else {
			throw MMError.badArguments(msg: "The provided context does not match the current index.")
		}
		
		return .init(context: context, objectIndex: self)
	}
	
	/// Filter the contents of the object index, returning a collection representing the results.  Pass `nil` to return an unfiltered collection.
	private static var MinimumSearchTextLength: Int { 3 }
	public func filtered(by filterCriteria: MMFilterCriteria?) async throws -> MMExhibitCollection {
		guard let filterCriteria = filterCriteria,
			  ((filterCriteria.searchText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.MinimumSearchTextLength ||
			   filterCriteria.creationYear != nil) else {
			return self.fullIndex
		}
		
		// - search the index
		var offsets: [Int] = []
		for i in 0..<objectList.count {
			if Task.isCancelled { break }
			guard MMExhibitCollection.includeInCollection(exhibit: objectList[i], criteria: filterCriteria) else { continue }
			offsets.append(i)
		}
		
		return .init(context: .init(indexId: self.id, criteria: filterCriteria, _offsets: offsets), objectIndex: self)
	}
}

/*
 *  Types
 */
extension MMObjectIndex {
	// - the columns from the file that are used for indexing
	private enum IndexedColumn : CaseIterable {
		case objectNumber
		case isHighlight
		case isTimelineWork
		case isPublicDomain
		case objectID
		case department
		case accessionYear
		case objectName
		case title
		case culture
		case artistDisplayName
		case artistDisplayBio
		case objectBeginDate
		case objectEndDate
		case medium
		case linkResource
		case tags
		
		/*
		 *  Attempt to map for a specific column.
		 */
		init?(for column: String) {
			guard let c = Self.columnMap[column] else {
				return nil
			}
			self = c
		}
		
		private static let columnMap: [String : IndexedColumn] = {
			var ret: [String : IndexedColumn] = [:]
			for ic in IndexedColumn.allCases {
				ret[ic.columnName] = ic
			}
			return ret
		}()
				
		// - these *must* match the columns in the first row of the file.
		private var columnName: String {
			switch self {
			case .objectNumber:
				return "Object Number"
				
			case .isHighlight:
				return "Is Highlight"
				
			case .isTimelineWork:
				return "Is Timeline Work"
				
			case .isPublicDomain:
				return "Is Public Domain"
				
			case .objectID:
				return "Object ID"
				
			case .department:
				return "Department"
				
			case .accessionYear:
				return "AccessionYear"
				
			case .objectName:
				return "Object Name"
				
			case .title:
				return "Title"
				
			case .culture:
				return "Culture"
				
			case .artistDisplayName:
				return "Artist Display Name"
				
			case .artistDisplayBio:
				return "Artist Display Bio"
				
			case .objectBeginDate:
				return "Object Begin Date"
				
			case .objectEndDate:
				return "Object End Date"
				
			case .medium:
				return "Medium"
				
			case .linkResource:
				return "Link Resource"
				
			case .tags:
				return "Tags"
			}
		}
	}
}

/*
 *  Testing support.
 */
extension MMObjectIndex {
	/*
	 *  Allocate an index for UI design and testing.
	 */
	static func createSamplingIndex() -> MMObjectIndex {
		let ret = MMObjectIndex()

		// - the principle here is to use *constant* data so that UI and testing occurs with
		//   predictable values that exercise the different field combinations fully.
		/// ...but ONLY in debug mode so we don't ship with these items.
		#if DEBUG
		
		ret.addReferenceToIndex(.init(objectID: 33, accessionNumber: "64.62", isHighlight: false, isTimelineWork: false, isPublicDomain: true, department: "American Classic", accessionYear: 1964, objectName: "Bust", title: "Bust of Abraham Lincoln", culture: "American", artistDisplayName: "James Gillinder and Sons", artistDisplayBio: "American, 1861–ca. 1930", objectBeginDate: 1876, objectEndDate: 1876, medium: "Pressed Glass", linkResource: "http://www.metmuseum.org/art/collection/search/33", tags: ["Men", "Abraham Lincoln", "Portraits"]))
		
		ret.addReferenceToIndex(.init(objectID: 65739, accessionNumber: "91.1.32", isHighlight: false, isTimelineWork: true, isPublicDomain: true, department: "Asian Art", accessionYear: 1891, objectName: "Fukusa (Gift Wrapper)", title: nil, culture: "Japan", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1767, objectEndDate: 1833, medium: "Silk, metallic thread", linkResource: "http://www.metmuseum.org/art/collection/search/65730", tags: ["Flowers"]))
		
		ret.addReferenceToIndex(.init(objectID: 194273, accessionNumber: "17.190.1777", isHighlight: true, isTimelineWork: false, isPublicDomain: true, department: "European Sculpture and Decorative Arts", accessionYear: 1917, objectName: "Butter churn", title: "Butter churn", culture: "French, Rouen", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1730, objectEndDate: 1730, medium: "Faience (tin-glazed earthenware)", linkResource: "http://www.metmuseum.org/art/collection/search/194273", tags: ["Coat of Arms"]))
		
		ret.addReferenceToIndex(.init(objectID: 213018, accessionNumber: "06.1199.1", isHighlight: true, isTimelineWork: true, isPublicDomain: true, department: "European Sculpture and Decorative Arts", accessionYear: 1917, objectName: "Border", title: "Border with scenes from the Life of Christ", culture: "Southern German", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1627, objectEndDate: 1627, medium: "Silk and wool on wool", linkResource: "http://www.metmuseum.org/art/collection/search/213018", tags: ["Flowers", "Angels", "Christ"]))
		
		ret.addReferenceToIndex(.init(objectID: 414930, accessionNumber: "59.585.1", isHighlight: false, isTimelineWork: false, isPublicDomain: true, department: "Drawings and Prints", accessionYear: 1917, objectName: "Print", title: "Head of a Young Man", culture: nil, artistDisplayName: "Gilles Demarteau|François Boucher", artistDisplayBio: "French, Liège 1722–1776 Paris|French, Paris 1703–1770 Paris", objectBeginDate: 1737, objectEndDate: 1776, medium: "Crayon-manner etching printed in red ink", linkResource: "http://www.metmuseum.org/art/collection/search/414930", tags: []))
		
		ret.addReferenceToIndex(.init(objectID: 460313, accessionNumber: "1975.1.2452", isHighlight: true, isTimelineWork: false, isPublicDomain: true, department: "Robert Lehman Collection", accessionYear: 1975, objectName: "Furisode", title: "Furisode", culture: "Japanese", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1800, objectEndDate: 1900, medium: "Possibly beni-dyed light red (orange) silk, figured satin weave, embroidered and couched in silvered and gilt metallic thread (wound around a white silk fiber core).  Needlework in satin stitch in shades of green, dark blue, off-white, and light brown; areas of padding; yuzen dyeing, and stenciled imitation tie-dyeing throughout.", linkResource: "http://www.metmuseum.org/art/collection/search/460313", tags: ["Cranes", "Trees"]))
		
		ret.addReferenceToIndex(.init(objectID: 468417, accessionNumber: "52.69", isHighlight: false, isTimelineWork: true, isPublicDomain: true, department: "Medieval Art", accessionYear: 1952, objectName: "Tapestry", title: "The Battle with the Sagittary and the Conference at Achilles' Tent (from Scenes from the Story of the Trojan War)", culture: "South Netherlandish", artistDisplayName: "Jean or Pasquier Grenier", artistDisplayBio: nil, objectBeginDate: 1467, objectEndDate: 1493, medium: "Wool warp, wool wefts with a few silk wefts", linkResource: "http://www.metmuseum.org/art/collection/search/468417", tags: ["Trojan War", "Tents", "Horses", "Battles"]))
		
		ret.addReferenceToIndex(.init(objectID: 546721, accessionNumber: "15.3.383", isHighlight: true, isTimelineWork: false, isPublicDomain: true, department: "Egyptian Art", accessionYear: nil, objectName: "Figurine, two hippopotomi", title: "Two hippopotami figurine", culture: nil, artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: -1700, objectEndDate: -1700, medium: "Ivory, paint", linkResource: "http://www.metmuseum.org/art/collection/search/546720", tags: ["Heads"]))
		
		ret.addReferenceToIndex(.init(objectID: 644211, accessionNumber: "63.350.207.145.1.211", isHighlight: false, isTimelineWork: false, isPublicDomain: true, department: "Drawings and Prints", accessionYear: 1963, objectName: "Print", title: "Actress wearing white cloth bonnet, from the Actors and Actresses series (N145-1) issued by Duke Sons & Co. to promote Cross Cut Cigarettes", culture: nil, artistDisplayName: "W. Duke, Sons & Co.", artistDisplayBio: "New York and Durham, N.C.", objectBeginDate: 1880, objectEndDate: 1889, medium: "Albumen photograph", linkResource: "http://www.metmuseum.org/art/collection/search/644209", tags: ["Portraits", "Women", "Acresses"]))
		
		ret.addReferenceToIndex(.init(objectID: 721532, accessionNumber: "2011.604.1.8354", isHighlight: false, isTimelineWork: false, isPublicDomain: true, department: "Greek and Roman Art", accessionYear: 2011, objectName: "Kylix fragment", title: "Terracotta fragment of a kylix (drinking cup)", culture: "Greek, Attic", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: -530, objectEndDate: -300, medium: "Terracotta", linkResource: "http://www.metmuseum.org/art/collection/search/721532", tags: []))
		
		#endif
		
		return ret
	}
	
	/*
	 *  Allocate an exhibit for UI design and testing.
	 */
	static func createSampleExhibit() -> MMExhibit? {
		#if DEBUG
			// - the strategy is to use a real one inlined here with replaced images that are generated
			//   and saved locally to avoid the network costs during UI design work.
			let pImage: String = self.generateSampleImage(sized: .init(width: 1916, height: 3992), named: "sample-big", seed: 1)?.absoluteString ?? ""
			let pSmall: String = self.generateSampleImage(sized: .init(width: 299, height: 623), named: "sample-small", seed: 1)?.absoluteString ?? ""
			let othImages: [String] = [
				self.generateSampleImage(sized: .init(width: 2048, height: 1024), named: "sample-other-1", seed: 2)?.absoluteString ?? "",
				self.generateSampleImage(sized: .init(width: 712, height: 1500), named: "sample-other-2", seed: 3)?.absoluteString ?? "",
				self.generateSampleImage(sized: .init(width: 4000, height: 4000), named: "sample-other-3", seed: 6)?.absoluteString ?? ""
			]
			let obj = MMObject(objectID: 45734, isHighlight: false, accessionNumber: "36.100.45", accessionYear: "1936", isPublicDomain: true, primaryImage: pImage, primaryImageSmall: pSmall, additionalImages: othImages, constituents: [.init(constituentID: 11986, role: "Artist", name: "Kiyohara Yukinobu", constituentULAN_URL: "http://vocab.getty.edu/page/ulan/500034433", constituentWikidata_URL: "https://www.wikidata.org/wiki/Q11560527", gender: "Female")], department: "Asian Art", objectName: "Hanging scroll", title: "Quail and Millet", culture: "Japan", period: "Edo period (1615–1868)", dynasty: "", reign: "", portfolio: "", artistRole: "Artist", artistPrefix: "", artistDisplayName: "Kiyohara Yukinobu", artistDisplayBio: "Japanese, 1643–1682", artistSuffix: "", artistAlphaSort: "Kiyohara Yukinobu", artistNationality: "Japanese", artistBeginDate: "1643", artistEndDate: "1682", artistGender: "Female", artistWikidata_URL: "https://www.wikidata.org/wiki/Q11560527", artistULAN_URL: "http://vocab.getty.edu/page/ulan/500034433", objectDate: "late 17th century", objectBeginDate: 1667, objectEndDate: 1682, medium: "Hanging scroll; ink and color on silk", dimensions: "46 5/8 x 18 3/4 in. (118.4 x 47.6 cm)", measurements: [.init(elementName: "Overall", elementDescription: nil, elementMeasurements: .init(Height: 118.4, Length: nil, Width: 47.6))], creditLine: "The Howard Mansfield Collection, Purchase, Rogers Fund, 1936", geographyType: "", city: "", state: "", county: "", country: "", region: "", subregion: "", locale: "", locus: "", excavation: "", river: "", classification: "Paintings", rightsAndReproduction: "", linkResource: "", metadataDate: "2022-10-20T04:55:06.267Z", repository: "Metropolitan Museum of Art, New York, NY", objectURL: "https://www.metmuseum.org/art/collection/search/45734", tags: [.init(term: "Birds", AAT_URL: "http://vocab.getty.edu/page/aat/300266506", Wikidata_URL: "https://www.wikidata.org/wiki/Q5113")], objectWikidata_URL: "https://www.wikidata.org/wiki/Q29910832", isTimelineWork: false, GalleryNumber: "")
			return MMExhibit(object: obj, owner: MetModel.samplingIndex)
		#else
			return nil
		#endif
	}
	
	#if DEBUG
	/*
	 *  Generate sample images.
	 *  - NOTE: the seed is used for predictable randomization of the color/content.
	 */
	static func generateSampleImage(sized: CGSize, named: String, seed: UInt) -> URL? {
		guard let uBase = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
			MMLog.error("Failed to get access to the cache directory.")
			return nil
		}
		let fURL = URL(filePath: uBase.path(percentEncoded: false)).appending(component: "\(named).jpeg")
		guard !FileManager.default.fileExists(atPath: fURL.path(percentEncoded: false)) else { return fURL }
		#if os(macOS)
		let img = NSImage(size: .init(width: sized.width, height: sized.height), flipped: false) { rc in
			// - background
			let colors: [NSColor] = [.orange, .cyan, .purple, .red, .blue, .green, .gray, .magenta]
			colors[Int(seed) % colors.count].setFill()
			NSBezierPath.fill(rc)
			
			// - badge for something to look at.
			let sfImgs: [String] = ["bolt", "face.smiling", "car.side", "person", "computermouse", "network", "dog"]
			let img 		     = NSImage(systemSymbolName: sfImgs[Int(seed) % sfImgs.count], accessibilityDescription: nil)
			let minSide = Swift.min(rc.size.width, rc.size.height)
			let minDim  = minSide / 2
			let ar 	    = (img?.size.width ?? 0.0) / (img?.size.height ?? 1.0)
			var rcBadge: NSRect
			if rc.size.width > rc.size.height {
				rcBadge = .init(x: 0, y: 0, width: minDim * ar, height: minDim)
			}
			else {
				rcBadge = .init(x: 0, y: 0, width: minDim, height: minDim / ar)
			}
			rcBadge = rcBadge.offsetBy(dx: (rc.size.width - rcBadge.width) / 2, dy: (rc.size.height - rcBadge.height) / 2).integral
			
			// ...as a template image.
			if let ctx = NSGraphicsContext.current, let cgImage = img?.cgImage(forProposedRect: &rcBadge, context: NSGraphicsContext.current, hints: nil) {
				ctx.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
				ctx.cgContext.clip(to: rcBadge, mask: cgImage)
				NSColor.white.setFill()
				NSBezierPath.fill(rc)
				NSGraphicsContext.current?.cgContext.endTransparencyLayer()
			}
			
			return true
		}
		
		guard let tiffData = img.tiffRepresentation,
			  let bImgRep = NSBitmapImageRep(data: tiffData),
			  let data = bImgRep.representation(using: .jpeg, properties: [:]) else {
			MMLog.error("Missing required sample bitmap image representation.")
			return nil
		}
		do {
			try data.write(to: fURL, options: .atomic)
		}
		catch {
			MMLog.error("Failed to generate a sample image.  \(error.localizedDescription)")
			return nil
		}
		
		return fURL
		#else
			return nil
		#endif
	}
	#endif
}

/*
 *  Internal implementation.
 */
extension MMObjectIndex : MMExhibitCacheOwnable {
	/*
	 *  Read a line from the file.
	 *  - DESIGN: the newline characters are *not* automatically discarded because
	 *            some rows may use strings to express multi-line column data.
	 */
	private func readLine() throws -> String? {
		guard let fStream = fStream else {
			throw MMError.invalidFile
		}
		
		let BufSize: Int = 8192
		let ptr 	     = UnsafeMutablePointer<CChar>.allocate(capacity: BufSize)
		defer {
			ptr.deallocate()
		}
		ptr.initialize(repeating: CChar(0), count: BufSize)
		guard let oneLine = fgets(ptr, Int32(BufSize), fStream) else {
			let errNo = ferror(self.fStream)
			guard errNo == 0 else {
				throw MMError.fileError(errno: errNo)
			}
			
			// - end of file
			return nil
		}
		
		guard let sLine = String(validatingUTF8: oneLine)?.trimmingCharacters(in: .whitespaces) else {
			throw MMError.badFormat(msg: .mmLocalized(localized: "The source data is not valid UTF-8."))
		}

		return sLine
	}
	
	/*
	 *  Read from the file and attempt to cache either:
	 * 		(1) all of the columns in a single line or
	 *  	(2) enough columns to satisfy the header-specified column count.
	 *  - Returns `false` if no columns are available.
	 */
	private func cacheColumns(asHeader isHeader: Bool) throws -> Bool {
		var updCache: [String] = columnCache
		var curCol 	  		   = ""
		var isEscaped 		   = false
		
		// - the challenge with this parsing is the use of escape characters, specifically double-quotes
		//   to represent a string that may include commas and newlines.  That requires a loop
		//   for iterating over the lines until we fill the expected number of columns.
		while updCache.count == 0 || (!isHeader && updCache.count < self.columnCount) {
			guard let text = try readLine() else { break }
			self.lineCount = (lineCount ?? 0) + 1
		
			for c in text {
				if c == "\"" {
					isEscaped.toggle()
				}
				else if isEscaped || (c != "," && !c.isNewline) {
					curCol.append(c)
				}
				
				// ...end of column
				if c == "," && !isEscaped {
					updCache.append(curCol.trimmingCharacters(in: .whitespacesAndNewlines))
					curCol = ""
				}
			}
			
			// - unless we're crossing line boundaries.
			// - NOTE:  If a row doesn't have a last column after its final comma delimiter, it
			//   will appear as just a comma followed by newline.  The implication is there is
			//   an _empty column value_ there if we're not expecting to escape across two lines.
			if !isEscaped {
				// ...when not escaping and there is data, always add it.
				// ...with the caveat if we should have a final column, but it is empty,
				//    add that special case also.
				let lastCol = curCol.trimmingCharacters(in: .whitespacesAndNewlines)
				if !lastCol.isEmpty || (!isHeader && updCache.count < self.columnCount) {
					updCache.append(lastCol)
				}
			}
		}
		
		self.columnCache = updCache
		return !updCache.isEmpty
	}
	
	/*
	 *  Read a specific number of columns from a line.
	 */
	private func readColumnarLine(asHeader isHeader: Bool) throws -> [String]? {
		// - cache as many as possible.
		guard try cacheColumns(asHeader: isHeader) else { return nil }
		
		
		let ret: [String]
		if isHeader {
			// ...intended for the header, just return one line's worth.
			ret 			 = self.columnCache
			self.columnCache = []
		}
		else {
			// ...every other row has specific requirements and allow for
			//    an abbreviated final row, just for completeness.
			guard self.columnCache.count >= self.columnCount else { return nil }
			ret = Array<String>(self.columnCache.prefix(self.columnCount))
			self.columnCache.removeFirst(self.columnCount)
		}
		
		return ret
	}
	
	/*
	 *  Read a single line from the file, parsing columns known to be indexed.
	 */
	private func readIndexedLine() throws -> [IndexedColumn : String]? {
		guard let headerMap = headerMap else {
			throw MMError.invalidFile
		}

		guard let cols = try readColumnarLine(asHeader: false) else { return nil }
		
		var ret: [IndexedColumn : String] = [:]
		for ic in IndexedColumn.allCases {
			guard let mc = headerMap[ic] else {
				assert(false, "The column names should have alredy been verified.")
				throw MMError.failedAssertion
			}
			let colItem = cols[mc]
			ret[ic] = colItem.isEmpty ? "" : colItem
		}
		return ret
	}
	
	/*
	 *  Perform file indexing.
	 */
	private func parseAndIndexFile(receivingStatus: StatusCallback) async throws {
		// 1. Count the lines to be able to establish progress
		var totalCount = 0
		while let _ = try readLine() {
			totalCount += 1
		}
		guard totalCount > 1 else {
			throw MMError.badFormat(msg: .mmLocalized(localized: "The object index has no content."))
		}
		guard fseek(self.fStream, 0, SEEK_SET) == 0 else {
			throw MMError.fileError(errno: ferror(self.fStream))
		}
				
		// - 2.  Map header items to offsets in each row
		guard let hdrItems = try readColumnarLine(asHeader: true) else {
			throw MMError.badFormat(msg: .mmLocalized(localized: "The object index is missing a header row."))
		}
		var headerMap: [IndexedColumn : Int] = [:]
		for i in 0..<hdrItems.count {
			let col = hdrItems[i].trimmingCharacters(in: .controlCharacters)		// - the first item is going to have UTF-8 control characters.
			guard let ic = IndexedColumn(for: col) else {
				continue
			}
			headerMap[ic] = i
		}
		self.columnCount = hdrItems.count
		self.headerMap 	 = headerMap
		receivingStatus(.started(totalCount: totalCount))
		var rowCount = 1
		receivingStatus(.progress(row: rowCount, totalCount: totalCount))

		// - 3.  Read each line and parse it into a reference if it is valid.
		let dBegin: Date = .init()
		var skipped: Int = 0
		while true {
			guard let row = try readIndexedLine() else { break }
			if let ref = rowToReference(row, rowNumber: rowCount - 1) {
				addReferenceToIndex(ref)
			}
			else {
				skipped += 1
			}
			rowCount += 1
			receivingStatus(.progress(row: rowCount, totalCount: totalCount))
		}
		
		// - 4.  Sorting
		self.objectList.sort { $0.sortText < $1.sortText }
		
		// - 5.  Final rate calculation
		let diff = Date().timeIntervalSince(dBegin)
		let rVal = Double(rowCount) / Double(diff)
		let indexRate = !rVal.isNaN ? rVal : 0.0
		receivingStatus(.completed(skipped: skipped, indexed: objectList.count, indexingRate: indexRate))
		
		// ...close the file stream
		fclose(self.fStream)
		self.fStream = nil
	}
		
	/*
	 *  Convert a MetObjects text item to a boolean.
	 */
	private static func asMOBool(_ text: String?) -> Bool {
		// ...they use an uppercased first letter
		return text?.lowercased() == "true"
	}
	
	/*
	 *  Convert the row into an object reference if is meets the criteria.
	 */
	private func rowToReference(_ row: [IndexedColumn : String], rowNumber: Int) -> MMExhibitRef? {
		// - the idea here is to normalize the data into strong types and omit
		//   records that won't be used for this app.
		
		// - 1. the conversions when necessary
		let accessionNumber = row[.objectNumber]				// ... they use different terminology in CSV versus the site.
		let isHighlight 	= Self.asMOBool(row[.isHighlight])
		let isTimelineWork  = Self.asMOBool(row[.isTimelineWork])
		let isPublicDomain  = Self.asMOBool(row[.isPublicDomain])
		let department 		= row[.department]
		
		var objectId: UInt?
		if let oId = row[.objectID], let nId = UInt(oId) {
			objectId = nId
		}
		
		var accessionYear: UInt?
		if let aYear = row[.accessionYear], !aYear.isEmpty, let yVal = UInt(aYear) {
			accessionYear = yVal
		}
		
		let title = row[.title]?.asSanitizedForDisplay
		let name  = row[.objectName]?.asSanitizedForDisplay
		
		let hasNameTitle	= !(title?.isEmpty ?? true) || !(name?.isEmpty ?? true)
		let beginDate 		= textToMachineDate(row[.objectBeginDate])
		let endDate 		= textToMachineDate(row[.objectEndDate])
		let linkResource	= row[.linkResource]
		let tags:[String]   = !(row[.tags]?.isEmpty ?? true) ? (row[.tags] ?? "").components(separatedBy: "|") : []

		// - 2. filter what isn't used
		// ...omit items with incomplete data.
		guard let accessionNumber = accessionNumber, !accessionNumber.isEmpty, let department = department, let linkResource = linkResource,
			  let objectId = objectId, hasNameTitle, let beginDate = beginDate, let endDate = endDate else {
			return nil
		}
		
		// ...we're not using pieces out of the public domain to minimize licsensing concerns.
		guard isPublicDomain else {
			return nil
		}
		
		// - 3. create a reference to save the information
		return MMExhibitRef(objectID: objectId, accessionNumber: accessionNumber, isHighlight: isHighlight, isTimelineWork: isTimelineWork, isPublicDomain: isPublicDomain, department: department, accessionYear: accessionYear, objectName: name, title: title, culture: row[.culture], artistDisplayName: row[.artistDisplayName], artistDisplayBio: row[.artistDisplayBio], objectBeginDate: beginDate, objectEndDate: endDate, medium: row[.medium]?.asSanitizedForDisplay, linkResource: linkResource, tags: tags)
	}
	
	/*
	 *  Convert the provided text into a begin/end date.
	 */
	private func textToMachineDate(_ text: String?) -> Int? {
		guard let text = text, !text.isEmpty, let ret = Int(text) else {
			return nil
		}
		return ret
	}
	
	/*
	 *  Add the provided object to the index.
	 */
	private func addReferenceToIndex(_ ref: MMExhibitRef) {
		objectList.append(ref)
		objectMap[ref.objectID] = ref
	}
		
	/*
	 *  Convert an exhibit into a URL.
	 */
	private func exhibitURLFrom(_ exhibit: MMExhibitIdentifiable) -> URL? {
		guard let exhibitCacheURL = exhibitCacheURL else { return nil }
		return exhibitCacheURL.appending(path: "exhibit-\(exhibit.objectID).json")
	}
	
	/*
	 *  Retrieve an exhibit from local cache if it exists.
	 */
	private func exhibitFromCache(eRef: MMExhibitRef) -> MMExhibit? {
		do {
			if let eURL = exhibitURLFrom(eRef), FileManager.default.fileExists(atPath: eURL.path(percentEncoded: false)) {
				let data = try Data(contentsOf: eURL)
				let ret  = try MMExhibit.standardMMJSONDecoding(of: data)
				ret.cacheOwner = self
				return ret
			}
		}
		catch {
			MMLog.error("Failed to load an exhibit from local cache.  \(error.localizedDescription, privacy: .public)")
			if let dError = error as? MMErrorDebuggable, let dText = dError.mmDebuggableText {
				MMLog.debug("\(dText, privacy: .public)")
			}
		}
		return nil
	}
	
	/*
	 *  Save an exhibit to local cache if possible.
	 */
	private func saveExhibitToCache(exhibit: MMExhibit) {
		guard let eURL = exhibitURLFrom(exhibit) else { return }
		Task(priority: .background) {
			do {
				let eData = try exhibit.standardMMJSONEncoding()
				try eData.write(to: eURL, options: [.atomic])
			}
			catch {
				MMLog.error("Failed to save an exhibit to local cache.  \(error.localizedDescription, privacy: .public)")
			}
		}
	}
	
	/*
	 *  Convert a remote URL into a cache-local URL.
	 */
	private func fileURLFromRemoteURL(_ url: URL) -> URL? {
		guard let exhibitFileCacheURL = exhibitFileCacheURL else { return nil }
		let hash = url.absoluteString.shaHash
		let ext  = url.pathExtension
		return exhibitFileCacheURL.appending(path: "file-\(hash).\(ext.isEmpty ? "data" : ext)")
	}
	
	/*
	 *  Attempt to load a file from cache.
	 */
	private func fileFromCache(url: URL) -> Data? {
		do {
			if let fURL = fileURLFromRemoteURL(url), FileManager.default.fileExists(atPath: fURL.path(percentEncoded: false)) {
				return try Data(contentsOf: fURL)
			}
		}
		catch {
			MMLog.error("Failed to read the cache file \(self.fileURLFromRemoteURL(url)?.path(percentEncoded: false) ?? url.absoluteString).  \(error.localizedDescription, privacy: .public)")
		}
		return nil
	}
	
	/*
	 *  Save a file to the cache.
	 */
	private func saveFileToCache(_ result: MMNetworkClient.MetArtFileResult, fromURL url: URL) {
		guard let fURL = fileURLFromRemoteURL(url) else { return }
		Task(priority: .background) {
			do {
				if case .success(let data) = result {
					try data.write(to: fURL, options: [.atomic])
				}
			}
			catch {
				MMLog.error("Failed to save file data to local cache. \(error.localizedDescription, privacy: .public)")
			}
		}
	}
	
	/*
	 *  Retrieve a file object, first by cache and then by network.
	 */
	func queryMetArtFile(atURL url: URL) async -> MMNetworkClient.MetArtFileResult {
		if let cfData = fileFromCache(url: url) {
			return .success(cfData)
		}

		// ...not in cache, retrieve it and save it now.
		let ret = await MMNetworkClient.shared.queryMetArtFile(atURL: url)
		saveFileToCache(ret, fromURL: url)
		return ret
	}
}

/*
 *  Utilities.
 */
fileprivate extension String {
	// - the descriptive items sometimes have characters that limit their usefulness.
	var asSanitizedForDisplay: String? {
		guard !self.isEmpty else { return self }
		
		// - some items like name/title will have really weird prefixes and suffixes.
		let quoteCS: CharacterSet = .init(charactersIn: "[\'\"( ")
		return self.trimmingCharacters(in: quoteCS)
	}
}
