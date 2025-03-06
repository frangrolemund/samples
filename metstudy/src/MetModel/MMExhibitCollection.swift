//
//  MMExhibitCollection.swift
//  MetModel
// 
//  Created on 2/12/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/*
 *  DESIGN:  The purpose of the exhibit collection is to provide really efficient
 *  		 access to a list of objects (for the UI)  without performing significant
 * 		     numbers of copies. That is why it uses indirection based on its internal
 *			 context of items.  It is not Codable because it requires an object index,
 * 		  	 and don't want a unique instance for every one of these that are copied.
 *  DESIGN:  The collection and its associated items are built to be classes so that
 * 			 the memory usage, particularly of the generated descriptions, can be
 *  	     lazily constructed without incurring a much higher memory cost of
 * 	 		 persisting internal structures.
 */

///  A list of exhibit references from an object index.
public final class MMExhibitCollection : Equatable {
	///  Compare for equality.
	public static func == (lhs: MMExhibitCollection, rhs: MMExhibitCollection) -> Bool { lhs.context == rhs.context }
	
	///  The context that defines this collection.
	public let context: MMFilterContext
	
	///  Indicates whether pattern matching was applied to the index to generate the collection.
	public var isFiltered: Bool {
		guard let _ = context._offsets else {
			return false
		}
		return true
	}
	
	///  An empty, default collection.
	public static var `default`: MMExhibitCollection {
		return .init(context: .init(indexId: .init(), criteria: nil, _offsets: nil), objectIndex: .emptyIndex)
	}
	
	///  Ther full list of the sampling index.
	public static var samplingIndex: MMExhibitCollection {
		let sIndex = MetModel.samplingIndex
		return .init(context: .init(indexId: sIndex.id, criteria: nil, _offsets: nil), objectIndex: sIndex)
	}
	
	/*
	 *  Initialize the object.
	 */
	init(context: MMFilterContext, objectIndex: MMObjectIndex) {
		self.context 	 = context
		self.objectIndex = objectIndex
	}
	
	// - internal
	//... the attached object index
	private let objectIndex: MMObjectIndex
}

/*
 *  Accessors.
 */
extension MMExhibitCollection : RandomAccessCollection {
	/// The index of the first item.
	public var startIndex: Int { 0 }
	
	/// The index of the last item.
	public var endIndex: Int {
		return context._offsets?.count ?? objectIndex.objectList.count
	}
	
	/// The number of items in the collection.
	public var count: Int { endIndex }
	
	/// Retrieve an exhibit reference by its index.
	public subscript(index: Int) -> MMExhibitRef {
		// ...either from the context or just assume the full index
		let offset = context._offsets?[index] ?? index
		return objectIndex.objectList[offset]
	}
}

/*
 *  Internal implementation
 */
extension MMExhibitCollection {
	/*
	 *  Check if the exhibit matches the criteria.
	 *  DESIGN:  The matching algorithm for text search requires we consistently apply the check
	 *  		 against the same fields here and when the result is formatted later, so the code
	 * 			 all exists in one place here.
	 */
	static func includeInCollection(exhibit: MMExhibitRef, criteria: MMFilterCriteria?) -> Bool {
		guard let criteria = criteria else { return true }
		
		// DATE MATCHING
		// - use the date only to omit items when it is provided.
		if let cYear = criteria.creationYear, (cYear < exhibit.objectBeginDate || cYear > exhibit.objectEndDate) {
			return false
		}
		
		// TEXT MATCHING
		// - if no text is provided, it should match all records.
		guard let sValue = criteria.searchText?.trimmingCharacters(in: .whitespacesAndNewlines),
			  !sValue.isEmpty else { return true }
		
		// ... push the hard work for text matching into the framework with a more brute-forced approach, which will be optimized.
		let eText = exhibit.matchingText
		
		// ... separate the criteria into separate words, considering each
		var hasOneMatch: Bool = false
		for sText in sValue.split(separator: " ") {
			guard !sText.isEmpty else { continue }
			
			// - check for equivalence using a case-insensitive check
			if !eText.localizedCaseInsensitiveContains(sText) {
				// - when using AND-notation, all must match or this doesn't qualify.
				if criteria.matchingRule == .andMatch {
					return false
				}
				continue
			}
			
			// - when using OR-notation, only one item must match to qualify.
			if criteria.matchingRule == .orMatch {
				return true
			}
			
			// - successful match using AND-notation.
			hasOneMatch = true
		}
		
		// ... when using AND-notation, we need at least one.
		return hasOneMatch
	}
}

/*
 *  Utilities.
 */
fileprivate extension MMExhibitRef {
	var matchingText: String {
		"\(accessionNumber) \(department) \(objectName ?? "") \(title ?? "") \(culture ?? "") \(medium ?? "") \(tags.joined(separator: " ")) \(artistDisplayName ?? "") \(artistDisplayBio ?? "")"
	}
}
