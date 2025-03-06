//
//  MMFilterContext.swift
//  MetModel
// 
//  Created on 2/4/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/*
 *  DESIGN:  The context is 
 */


///  The result of a successful filtering request against an index.
public struct MMFilterContext : Codable, Equatable {
	/// Identification of the index that produced this context.
	public let indexId: UUID
		
	/// The filter parameters that produced this context.
	public let criteria: MMFilterCriteria?
	
	/*
	 *  Initialize the object.
	 */
	init(indexId: UUID, criteria: MMFilterCriteria?, _offsets: [Int]?) {
		self.indexId = indexId
		self.criteria = criteria
		self._offsets = _offsets
	}

	// - internal
	
	// ...the offsets into the object index list for matching items or
	//    `nil` to indicate all items.
	let _offsets: [Int]?
}
