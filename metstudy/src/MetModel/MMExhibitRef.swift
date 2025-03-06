//
//  MMExhibitRef.swift
//  MetModel
// 
//  Created on 1/18/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/// A single piece from the Met Art museum objects (index) file.  This is
/// a 'reference' because the index is not guaranteed to be current or fully
/// accurate with caveats on their GitHub page.   The intention of this entity
/// is to give clues about the qualities of an item, while expecting the REST
/// API to be called for more conclusive information.  Descriptions are taken
/// from the [Met Art REST API documentation](https://metmuseum.github.io).
public class MMExhibitRef : Codable, MMExhibitIdentifiable, MMObjectIdentifiable, Equatable {
	/// Test for equivalence.
	public static func == (lhs: MMExhibitRef, rhs: MMExhibitRef) -> Bool {
		lhs.objectID == rhs.objectID && lhs.accessionNumber == rhs.accessionNumber
	}
	
	/// Identifying number for each artwork (unique, can be used as key field).
	public let objectID: MMObjectIdentifier
	
	/// Identifying number for each artwork (not always unique).
	public let accessionNumber: String
	
	/// When "true" indicates a popular and important artwork in the collection.
	public let isHighlight: Bool
	
	/// Whether the object is on the Timeline of Art History website.
	public let isTimelineWork: Bool
	
	/// When "true" indicates an artwork in the Public Domain.
	public let isPublicDomain: Bool
	
	/// Indicates The Met's curatorial department responsible for the artwork.
	public let department: String
	
	/// Year the artwork was acquired.
	public let accessionYear: UInt?
	
	/// Describes the physical type of the object.
	public let objectName: String?
	
	/// Title, identifying phrase, or name given to a work of art.
	public let title: String?
	
	/// Information about the culture, or people from which an object was created.
	public let culture: String?
	
	/// Artist name in the correct order for display.
	public let artistDisplayName: String?
	
	/// Nationality and life dates of an artist, also includes birth and death city when known.
	public let artistDisplayBio: String?
	
	/// Machine readable date indicating the year the artwork was started to be created.
	public let objectBeginDate: Int
	
	/// Machine readable date indicating the year the artwork was completed (may be the same year or different year than the objectBeginDate).
	public let objectEndDate: Int
	
	/// Formatted text indicating the dates of creation/completion.
	public var objectCreationDates: String {
		let sameEpoch = (objectBeginDate >= 0) == (objectEndDate >= 0)
		let bYear 	  = abs(objectBeginDate)
		let eYear 	  = abs(objectEndDate > objectBeginDate ? objectEndDate : objectBeginDate)
		return sameEpoch ? (eYear != bYear) ? 
								"\(bYear)-\(eYear)\(bYear < 0 ? Self.BCSuffix : "")" :
									"\(bYear)\(bYear < 0 ? Self.BCSuffix : "")" :
							"\(bYear)\(Self.BCSuffix)-\(eYear)\(Self.ADSuffix)"
	}
	
	/// Artist name removing special characters and better suited for display.
	public var artistDisplayNameNormalized: String? {
		return artistDisplayName?.replacingOccurrences(of: "|", with: "; ")
	}
	
	/// Artist bio removing special characters and better suited for display.
	public var artistDisplayBioNormalized: String? {
		return artistDisplayBio?.replacingOccurrences(of: "|", with: "; ")
	}
	
	private static let BCSuffix: String = String(localized: "B.C.")
	private static let ADSuffix: String = String(localized: "A.D.")
	
	/// Refers to the materials that were used to create the artwork
	public let medium: String?
	
	/// URL to object's page on metmuseum.org.
	public let linkResource: String
	
	/// An array of subject keyword tags associated with the object and their respective AAT URL.
	public let tags: [String]
	
	/// Initialize the object.
	public init(objectID: UInt, accessionNumber: String, isHighlight: Bool, isTimelineWork: Bool, isPublicDomain: Bool, department: String, accessionYear: UInt?, objectName: String?, title: String?, culture: String?, artistDisplayName: String?, artistDisplayBio: String?, objectBeginDate: Int, objectEndDate: Int, medium: String?, linkResource: String, tags: [String]) {
		self.objectID 			= objectID
		self.accessionNumber	= accessionNumber
		self.isHighlight 		= isHighlight
		self.isTimelineWork 	= isTimelineWork
		self.isPublicDomain 	= isPublicDomain
		self.department 		= department
		self.accessionYear 		= accessionYear
		self.objectName			= !(objectName?.isEmpty ?? true) ? objectName : nil
		self.title 				= !(title?.isEmpty ?? true) ? title : nil
		self.culture 			= !(culture?.isEmpty ?? true) ? culture : nil
		self.artistDisplayName 	= !(artistDisplayName?.isEmpty ?? true) ? artistDisplayName : nil
		self.artistDisplayBio 	= !(artistDisplayBio?.isEmpty ?? true) ? artistDisplayBio : nil
		self.objectBeginDate 	= objectBeginDate
		self.objectEndDate 		= objectEndDate
		self.medium 			= !(medium?.isEmpty ?? true) ? medium : nil
		self.linkResource 		= linkResource
		self.tags 				= tags
	}
	
	// - internal
	var sortText: String { ((self.title ?? "") + " " + (self.objectName ?? "")).lowercased() }
}

public protocol MMExhibitIdentifiable {
	/// Identifying number for each artwork (unique, can be used as key field).
	var objectID: MMObjectIdentifier { get }
}

/*
 *  Utilities
 */
extension MMExhibitRef : CustomStringConvertible {
	///  Return a textual definition of the object.
	public var description: String {
		"\(self.objectID)-\(self.accessionNumber);\(self.isHighlight ? "Highlighted" : "");\(self.isTimelineWork ? "Timeline" : "");\(self.isPublicDomain ? "Public-Domain" : "");\(self.department );\(self.accessionYear ?? 0);\(self.objectName ?? "");\(self.title ?? "");\(self.culture ?? "");\(self.artistDisplayName ?? "");\(self.artistDisplayBio ?? "");\(self.objectBeginDate)-\(self.objectEndDate);\(self.medium ?? "");\(self.linkResource);\(self.tags.joined(separator: "|"));"
	}
}
