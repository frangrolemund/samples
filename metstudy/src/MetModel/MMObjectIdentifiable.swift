//
//  MMObjectIdentifiable.swift
//  MetModel
// 
//  Created on 1/18/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation

/// The unique identification provided for Met Art exhbits.
public typealias MMObjectIdentifier = UInt

///  Defines the common structure of exported object definitions as defined
///  by the [Met Art REST API](https://metmuseum.github.io).
public protocol MMObjectIdentifiable : Identifiable {
	/// Identifying number for each artwork (unique, can be used as key field)
	var objectID: MMObjectIdentifier { get }
			
	/// Identifying number for each artwork (not always unique).
	var accessionNumber: String { get }
	
	/// When `true` indicates a popular and important artwork in the collection.
	var isHighlight: Bool { get }
	
	/// Whether the object is on the Timeline of Art History website.
	var isTimelineWork: Bool { get }
	
	/// When `true` indicates an artwork in the Public Domain.
	var isPublicDomain: Bool { get }
	
	/// Indicates The Met's curatorial department responsible for the artwork.
	var department: String { get }
	
	/// Year the artwork was acquired.
	var accessionYear: UInt? { get }
	
	/// Describes the physical type of the object.
	var objectName: String? { get }
	
	/// Title, identifying phrase, or name given to a work of art.
	var title: String? { get }
	
	/// Information about the culture, or people from which an object was created.
	var culture: String? { get }
	
	/// Artist name in the correct order for display.
	var artistDisplayName: String? { get }
	
	/// Nationality and life dates of an artist, also includes birth and death city when known.
	var artistDisplayBio: String? { get }
	
	/// Machine readable date indicating the year the artwork was started to be created.
	var objectBeginDate: Int { get }
	
	/// Machine readable date indicating the year the artwork was completed (may be the same year or different year than the objectBeginDate).
	var objectEndDate: Int { get }
	
	/// Refers to the materials that were used to create the artwork.
	var medium: String? { get }
	
	/// URL to object's page on metmuseum.org.
	var linkResource: String { get }
	
	/// An array of subject keyword tags associated with the object and their respective AAT URL.
	var tags: [String] { get }
}

// - convenience
public extension MMObjectIdentifiable {
	var id: String { "\(self.objectID)" }
}
