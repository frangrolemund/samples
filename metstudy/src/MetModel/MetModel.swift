//
//  MetModel.swift
//  MetModel
// 
//  Created on 1/13/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved.
//

import Foundation

/// Defines the data model and processing for interfacing with the public data set
/// of the Metropolitan Museum of Art as exported by its [Art Collection API](https://metmuseum.github.io).
/// As specified by the MetArt [Terms of Use](https://www.metmuseum.org/policies/terms-and-conditions), the
/// works may be under an Opan Access license or be under a non-commercial copyright.  In the interest of
/// ensuring compliance, this interface mandates its apps assume the more strict of these, which is
/// the _non-commercial requirement_ for any downloaded content or resources.
public class MetModel {
	///  Read a [MetObjects.csv](https://github.com/metmuseum/openaccess) file
	///  and build an index of its content.
	public static func readIndex(from url: URL, receivingStatus: MMObjectIndex.StatusCallback? = nil) async throws -> MMObjectIndex {
		return try await MMObjectIndex.read(from: url, receivingStatus: receivingStatus)
	}
		
	/// An index that can be used for UI design or testing  containing a constant-sized list of sample exhibits.
	public static let samplingIndex: MMObjectIndex = MMObjectIndex.createSamplingIndex()
	
	/// An exhibit that can be used for UI design or testing.
	public static let sampleExhibit: MMExhibit! = MMObjectIndex.createSampleExhibit()
}
