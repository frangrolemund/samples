//
//  MMObject.swift
//  MetModel
// 
//  Created on 2/24/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  An 'object' is the terminology of the MetArt REST API that
 *  represents a single exhibit in their collection.
 *  
 *  I'm using this terminology internally to ensure consistency
 *  with the back-end explanations.  It will precisely match the
 *  definitions at https://metmuseum.github.io/#object.
 *
 *  DESIGN: This clearly looks very similar to the MMExhibitRef with
 * 	 		good reason because they both represent the same data, but
 * 			since the content is slightly different between the two I
 * 			think it is important to differentiate them here.  The
 * 			reference is an indicator of the content, but this is the
 * 			'official' record.
 *
 *  DESIGN: These are built to be constant and fairly exact to the back-end
 *  		to reflect the origin of the information.
 */
struct MMObject : Codable {
	// - Identifying number for each artwork (unique, can be used as key field)
	let objectID: MMObjectIdentifier
	
	// - When "true" indicates a popular and important artwork in the collection.
	let isHighlight: Bool
	
	// - Identifying number for each artwork (not always unique)
	let accessionNumber: String
	
	// - Year the artwork was acquired.
	let accessionYear: String
	
	// - When "true" indicates an artwork in the Public Domain
	let isPublicDomain: Bool
	
	// - URL to the primary image of an object in JPEG format
	let primaryImage: String
	
	// - URL to the lower-res primary image of an object in JPEG format
	let primaryImageSmall: String
	
	// - An array containing URLs to the additional images of an object in JPEG format
	let additionalImages: [String]
	
	// - An array containing the constituents associated with an object.
	let constituents: [Constituent]?
	
	// - Indicates The Met's curatorial department responsible for the artwork
	let department: String
	
	// - Describes the physical type of the object
	let objectName: String
	
	// - Title, identifying phrase, or name given to a work of art
	let title: String
	
	// - Information about the culture, or people from which an object was created
	let culture: String
	
	// - Time or time period when an object was created
	let period: String
	
	// - Dynasty (a succession of rulers of the same line or family) under which an object was created
	let dynasty: String
	
	// - Reign of a monarch or ruler under which an object was created
	let reign: String
	
	// - A set of works created as a group or published as a series.
	let portfolio: String
	
	// - Role of the artist related to the type of artwork or object that was created
	let artistRole: String
	
	// - Describes the extent of creation or describes an attribution qualifier to the information given in the artistRole field
	let artistPrefix: String
	
	// - Artist name in the correct order for display
	let artistDisplayName: String
	
	// - Nationality and life dates of an artist, also includes birth and death city when known.
	let artistDisplayBio: String
	
	// - Used to record complex information that qualifies the role of a constituent, e.g. extent of participation by the Constituent (verso only, and followers)
	let artistSuffix: String
	
	// - Used to sort artist names alphabetically. Last Name, First Name, Middle Name, Suffix, and Honorific fields, in that order.
	let artistAlphaSort: String
	
	// - National, geopolitical, cultural, or ethnic origins or affiliation of the creator or institution that made the artwork
	let artistNationality: String
	
	// - Year the artist was born
	let artistBeginDate: String
	
	// - Year the artist died
	let artistEndDate: String
	
	// - Gender of the artist (currently contains female designations only)
	let artistGender: String
	
	// - Wikidata URL for the artist
	let artistWikidata_URL: String
	
	// - ULAN URL for the artist
	let artistULAN_URL: String
	
	// - Year, a span of years, or a phrase that describes the specific or approximate date when an artwork was designed or created
	let objectDate: String
	
	// - Machine readable date indicating the year the artwork was started to be created
	let objectBeginDate: Int
	
	// - Machine readable date indicating the year the artwork was completed (may be the same year or different year than the objectBeginDate)
	let objectEndDate: Int
	
	// - Refers to the materials that were used to create the artwork
	let medium: String
	
	// - Size of the artwork or object
	let dimensions: String
	
	// - Array of elements, each with a name, description, and set of measurements. Spatial measurements are in centimeters; weights are in kg.
	let measurements: [Measurement]?
	
	// - Text acknowledging the source or origin of the artwork and the year the object was acquired by the museum.
	let creditLine: String
	
	// - Qualifying information that describes the relationship of the place catalogued in the geography fields to the object that is being catalogued
	let geographyType: String
	
	// - City where the artwork was created
	let city: String
	
	// - State or province where the artwork was created, may sometimes overlap with County
	let state: String
	
	// - County where the artwork was created, may sometimes overlap with State
	let county: String
	
	// - Country where the artwork was created or found
	let country: String
	
	// - Geographic location more specific than country, but more specific than subregion, where the artwork was created or found (frequently null)
	let region: String
	
	// - Geographic location more specific than Region, but less specific than Locale, where the artwork was created or found (frequently null)
	let subregion: String
	
	// - Geographic location more specific than subregion, but more specific than locus, where the artwork was found (frequently null)
	let locale: String
	
	// - Geographic location that is less specific than locale, but more specific than excavation, where the artwork was found (frequently null)
	let locus: String
	
	// - The name of an excavation. The excavation field usually includes dates of excavation.
	let excavation: String
	
	// - River is a natural watercourse, usually freshwater, flowing toward an ocean, a lake, a sea or another river related to the origins of an artwork (frequently null)
	let river: String
	
	// - General term describing the artwork type.
	let classification: String
	
	// - Credit line for artworks still under copyright.
	let rightsAndReproduction: String
	
	// - URL to object's page on metmuseum.org
	let linkResource: String
	
	// - Date metadata was last updated (in ISO-8601 format)
	let metadataDate: String
	
	// - Location of the piece.
	let repository: String
	
	// - URL to object's page on metmuseum.org	"https://www.metmuseum.org/art/collection/search/547802"
	let objectURL: String
	
	// - An array of subject keyword tags associated with the object and their respective AAT URL
	let tags: [Tag]?
	
	// - Wikidata URL for the object
	let objectWikidata_URL: String
	
	// - Whether the object is on the Timeline of Art History website
	let isTimelineWork: Bool
	
	// - Gallery number, where available
	let GalleryNumber: String
}

/*
 *  Types
 */
extension MMObject {
	// - a benefactor or provider of an object.
	struct Constituent : Codable {
		// - a unique identifier
		let constituentID: Int
		
		// - service provided by the individual
		let role: String
		
		// - their full name (first and last)
		let name: String
		
		// - the 'Union List of Artists Names' online record.
		let constituentULAN_URL: String
		
		// - a link to the Wiki knowledgebase of parsable data.
		let constituentWikidata_URL: String
		
		// - the gender of the constituent, mostly just Female when it is provided.
		let gender: String?
	}
	
	// - a description of the bounds of an object.
	struct Measurement : Codable {
		// - the type of measurement
		let elementName: String
		
		// - extended descriptive measurement information.
		let elementDescription: String?
		
		// - the measurement values
		let elementMeasurements: Values
		
		struct Values : Codable {
			let Height: Double?
			let Length: Double?
			let Width: Double?
		}
	}
	
	// - a descriptive tag for an object.
	struct Tag : Codable {
		// - the tag name
		let term: String
		
		// - the 'Art and Architecture Thesaurus' online link.
		let AAT_URL: String?
		
		// - the WikiData link
		let Wikidata_URL: String?
	}
}
