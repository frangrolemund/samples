//
//  MMExhibit+Object.swift
//  MetModel
// 
//  Created on 2/26/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import Foundation

/*
 *  Accessors for the internal object data.
 *  DESIGN: This intends is to keep the internal type as exactly identical to the back-end
 * 			definition as possible, while insulating the callers from those constraints.
 *  DESIGN: I'm using computed properties instead of embedded ones here because most of
 *  		this instance is rarely displayed in a UI so I figured that it is better to
 *  		compute-on-demand for the less often used elements as a rule.
 */
extension MMExhibit {
	/// The MetArt identifier of the exhibit.
	public var objectID: MMObjectIdentifier { self.obj.objectID }
	
	/// When "true" indicates a popular and important artwork in the collection.
	public var isHighlight: Bool { self.obj.isHighlight }
	
	/// Identifying number for each artwork (not always unique).
	public var accessionNumber: String { self.obj.accessionNumber }
	
	/// Year the artwork was acquired.
	public var accessionYear: String { self.obj.accessionYear }
	
	/// When "true" indicates an artwork in the Public Domain.
	public var isPublicDomain: Bool { self.obj.isPublicDomain }
	
	// - URL to the primary image of an object in JPEG format.
	//   NOTE: I prefer to obscure this interface in favor of prioritizing the cache if available.
	var primaryImageURL: URL? { self.obj.primaryImage.isEmpty ? nil : URL(string: self.obj.primaryImage) }
	
	/// - URL to the small variant of the primary image in JPEG format.
	var primaryImageSmallURL: URL? { self.obj.primaryImageSmall.isEmpty ? nil : URL(string: self.obj.primaryImageSmall) }
	
	/// An array containing URLs to the additional images of an object in JPEG format.
	public var additionalImageURLs: [URL] { self.obj.additionalImages.compactMap({ URL(string: $0) }) }
	
	/// An array containing the constituents associated with an exhibit.
	public var constituents: [Constituent] { self.obj.constituents?.compactMap({Constituent(with: $0) }) ?? [] }
	
	/// Indicates The Met's curatorial department responsible for the artwork.
	public var department: String { self.obj.department }
	
	/// Describes the physical type of the exhibit.
	public var exhbitName: String? { self.eStringFrom(\.objectName) }
	
	/// Title, identifying phrase, or name given to a work of art.
	public var title: String? { self.eStringFrom(\.title) }
	
	/// Information about the culture, or people from which an object was created.
	public var culture: String? { self.eStringFrom(\.culture) }
	
	/// Time or time period when an object was created.
	public var period: String? { self.eStringFrom(\.period) }
	
	/// Dynasty (a succession of rulers of the same line or family) under which an object was created.
	public var dynasty: String? { self.eStringFrom(\.dynasty) }
	
	/// Reign of a monarch or ruler under which an object was created.
	public var reign: String? { self.eStringFrom(\.reign) }
	
	/// A set of works created as a group or published as a series.
	public var portfolio: String? { self.eStringFrom(\.portfolio) }
	
	/// Role of the artist related to the type of artwork or object that was created.
	public var artistRole: String? { self.eStringFrom(\.artistRole) }
	
	/// Describes the extent of creation or describes an attribution qualifier to the information given in the artistRole field.
	public var artistPrefix: String? { self.eStringFrom(\.artistPrefix) }
	
	/// Artist name in the correct order for display.
	public var artistDisplayName: String? { self.eStringFrom(\.artistDisplayName) }
	
	/// Nationality and life dates of an artist, also includes birth and death city when known.
	public var artistDisplayBio: String? { self.eStringFrom(\.artistDisplayBio) }
	
	/// Used to record complex information that qualifies the role of a constituent, e.g. extent of participation by the Constituent (verso only, and followers).
	public var artistSuffix: String? { self.eStringFrom(\.artistSuffix) }
	
	/// Used to sort artist names alphabetically. Last Name, First Name, Middle Name, Suffix, and Honorific fields, in that order.
	public var artistAlphaSort: String? { self.eStringFrom(\.artistAlphaSort) }
	
	/// National, geopolitical, cultural, or ethnic origins or affiliation of the creator or institution that made the artwork.
	public var artistNationality: String? { self.eStringFrom(\.artistNationality) }
	
	/// Year the artist was born.
	public var artistBeginDate: String? { self.eStringFrom(\.artistBeginDate) }
	
	/// Year the artist died.
	public var artistEndDate: String? { self.eStringFrom(\.artistEndDate) }
	
	/// Gender of the artist (currently contains female designations only).
	public var artistGender: String? { self.eStringFrom(\.artistGender) }
	
	/// Wikidata URL for the artist.
	public var artistWikidata_URL: URL? { URL(string: self.obj.artistWikidata_URL) }
	
	/// ULAN URL for the artist.
	public var artistULAN_URL: URL? { URL(string: self.obj.artistULAN_URL) }
	
	/// Year, a span of years, or a phrase that describes the specific or approximate date when an artwork was designed or created.
	public var objectDate: String { self.obj.objectDate }
	
	/// Machine readable date indicating the year the artwork was started to be created.
	public var objectBeginDate: Int { self.obj.objectBeginDate }
	
	/// Machine readable date indicating the year the artwork was completed (may be the same year or different year than the objectBeginDate).
	public var objectEndDate: Int { self.obj.objectEndDate }
	
	/// Refers to the materials that were used to create the artwork.
	public var medium: String? { self.eStringFrom(\.medium) }
	
	/// Size of the artwork or object.
	public var dimensions: String? { self.eStringFrom(\.dimensions) }
	
	/// Array of elements, each with a name, description, and set of measurements. Spatial measurements are in centimeters; weights are in kg.
	public var measurements: [Measurement] { self.obj.measurements?.map({.init(with: $0)} ) ?? [] }
	
	/// Text acknowledging the source or origin of the artwork and the year the object was acquired by the museum.
	public var creditLine: String? { self.eStringFrom(\.creditLine) }
	
	/// Qualifying information that describes the relationship of the place catalogued in the geography fields to the object that is being catalogued.
	public var geographyType: String? { self.eStringFrom(\.geographyType) }
	
	/// City where the artwork was created.
	public var city: String? { self.eStringFrom(\.city) }
	
	/// State or province where the artwork was created, may sometimes overlap with County.
	public var state: String? { self.eStringFrom(\.state) }
	
	/// County where the artwork was created, may sometimes overlap with State.
	public var county: String? { self.eStringFrom(\.county) }
	
	/// Country where the artwork was created or found.
	public var country: String? { self.eStringFrom(\.country) }
	
	/// Geographic location more specific than country, but more specific than subregion, where the artwork was created or found (frequently null).
	public var region: String? { self.eStringFrom(\.region) }
	
	/// Geographic location more specific than Region, but less specific than Locale, where the artwork was created or found (frequently null).
	public var subregion: String? { self.eStringFrom(\.subregion) }
	
	/// Geographic location more specific than subregion, but more specific than locus, where the artwork was found (frequently null).
	public var locale: String? { self.eStringFrom(\.locale) }
	
	/// Geographic location that is less specific than locale, but more specific than excavation, where the artwork was found (frequently null).
	public var locus: String? { self.eStringFrom(\.locus) }
	
	/// The name of an excavation. The excavation field usually includes dates of excavation.
	public var excavation: String? { self.eStringFrom(\.excavation) }
	
	/// River is a natural watercourse, usually freshwater, flowing toward an ocean, a lake, a sea or another river related to the origins of an artwork (frequently null).
	public var river: String? { self.eStringFrom(\.river) }
	
	/// General term describing the artwork type.
	public var classification: String? { self.eStringFrom(\.classification) }
	
	/// Credit line for artworks still under copyright.
	public 	var rightsAndReproduction: String? { self.eStringFrom(\.rightsAndReproduction) }
	
	/// URL to object's page on metmuseum.org
	public var linkResource: URL? { self.obj.linkResource.isEmpty ? nil : URL(string: self.obj.linkResource) }
	
	/// Date metadata was last updated (in ISO-8601 format).
	public var metadataDate: String? { self.eStringFrom(\.metadataDate) }
	
	/// Location of the piece.
	public var repository: String? { self.eStringFrom(\.repository) }
	
	/// URL to object's page on metmuseum.org
	public var objectURL: URL! { URL(string: self.obj.objectURL) }
	
	/// An array of subject keyword tags associated with the object and their respective AAT URL.
	public var tags: [Tag] { self.obj.tags?.map({.init(with: $0) }) ?? [] }
	
	/// Wikidata URL for the object.
	public var objectWikidata_URL: URL? { self.obj.objectWikidata_URL.isEmpty ? nil : URL(string: self.obj.objectWikidata_URL) }
	
	/// Whether the object is on the Timeline of Art History website.
	public var isTimelineWork: Bool { self.obj.isTimelineWork }
	
	/// Gallery number, where available.
	public var galleryNumber: String?  { self.eStringFrom(\.GalleryNumber) }
}

// - types
extension MMExhibit {
	/*
	 *  The object attributes are often empty strings for data that wasn't populated, which
	 *  is fine for most cases, but makes for ugly UI experiences, so this method will perform
	 *  a nil conversion for the non-data cases so the UI is clear about availability.
	 */
	private func eStringFrom<Value>(_ keyPath: KeyPath<MMObject, Value>) -> String? {
		guard let val = self.obj[keyPath: keyPath] as? String, !val.isEmpty else { return nil }
		return val
	}
	
	
	/// A benefactor or provider of an exhibit.
	public struct Constituent {
		/// A unique identifier
		public var constituentID: Int { self.con.constituentID }
		
		/// Service provided by the individual
		public var role: String? { self.con.role.isEmpty ? nil : self.con.role }
		
		/// Their full name (first and last)
		public var name: String? { self.con.name.isEmpty ? nil : self.con.name }
		
		/// The 'Union List of Artists Names' online record.
		public var constituentULAN_URL: URL? { URL(string: self.con.constituentULAN_URL) }
		
		/// A link to the Wiki knowledgebase of parsable data.
		public var constituentWikidata_URL: URL? { URL(string: self.con.constituentWikidata_URL) }
		
		/// The gender of the constituent, mostly just Female when it is provided.
		public var gender: String? { self.con.gender }
		
		/*
		 *  Internal initializer
		 */
		init(with objCon: MMObject.Constituent) {
			self.con = objCon
		}
		
		private let con: MMObject.Constituent
	}
	
	/// A description of the bounds of an exhibit.
	public struct Measurement {
		/// The type of measurement.
		public var elementName: String { self.value.elementName }
		
		/// Extended descriptive measurement information.
		public var elementDescription: String? { self.value.elementDescription }
		
		/// The measurement values
		public var elementMeasurements: Values { .init(height: self.value.elementMeasurements.Height,
													   length: self.value.elementMeasurements.Length,
													   width: self.value.elementMeasurements.Width)}
		
		/// Defines a single measured attribute of an exhibit.
		public struct Values {
			public let height: Double?
			public let length: Double?
			public let width: Double?
		}
		
		/*
		 *  Internal initializer.
		 */
		init(with value: MMObject.Measurement) {
			self.value = value
		}
		
		private let value: MMObject.Measurement
	}
	
	/// A descriptive tag for an exhibit.
	public struct Tag {
		/// The tag name
		public var term: String { self.tag.term }
		
		/// The 'Art and Architecture Thesaurus' online link.
		public var AAT_URL: URL? { self.tag.AAT_URL != nil ? URL(string: self.tag.AAT_URL!) : nil }
		
		// - the WikiData link
		public var Wikidata_URL: URL? { self.tag.Wikidata_URL != nil ? URL(string: self.tag.Wikidata_URL!) : nil }
		
		/*
		 *  Internal initializer.
		 */
		init(with tag: MMObject.Tag) {
			self.tag = tag
		}
		
		private let tag: MMObject.Tag
	}
}
