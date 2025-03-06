//
//  MMFilterCriteria.swift
//  MetModel
// 
//  Created on 2/4/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

///  Describes the desired exhibits from the index that include matching attributes.
public struct MMFilterCriteria : Codable, Equatable {
	/// Matches objects with the same text.
	public var searchText: String?
	
	/// Defines how the search text will apply matching when multiple words exist.
	public var matchingRule: MatchingRule
	
	/// Matches objects with an overlapping year of creation.
	public var creationYear: Int?
			
	/// Describes how the search text is interpreted for matching when it can be divided into
	/// multiple words that are separated by spaces.
	public enum MatchingRule : Codable {
		///  Matches when _any_ of the provided space-separated search items is included in the exhibit.
		case orMatch
		
		///  Matches when _all_ of the provided space-separated search items are included in the exhibit.
		case andMatch
	}
	
	/// Initialize the object.
	public init(searchText: String? = nil, matchingRule: MatchingRule = .andMatch, creationYear: Int? = nil) {
		self.searchText   = searchText
		self.matchingRule = matchingRule
		self.creationYear = creationYear
	}
}

/*
 *  Accessors.
 */
extension MMFilterCriteria {
	///  Indicates whether this filter has criteria assigned that can influence results.
	public var isFiltered: Bool {
		!(searchText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
			matchingRule != .andMatch ||
			creationYear != nil
	}
	
	///  Returns a mutated instance of the criteria with alternate search text.
	public func withSearchText(_ searchText: String?) -> MMFilterCriteria {
		var ret 	   = self
		ret.searchText = searchText
		return ret
	}
	
	///  Returns a mutated instance of the criteria with an alternate matching rule.
	public func withMatchingRule(_ matchingRule: MatchingRule) -> MMFilterCriteria {
		var ret 		 = self
		ret.matchingRule = matchingRule
		return ret
	}
	
	///  Returns a mutated instance of the criteria with an alternate creation year.
	public func withCreationYear(_ creationYear: Int?) -> MMFilterCriteria {
		var ret 		 = self
		ret.creationYear = creationYear
		return ret
	}
}
