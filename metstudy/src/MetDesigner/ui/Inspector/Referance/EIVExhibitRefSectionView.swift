//
//  EIVExhibitRefSectionView.swift
//  MetDesigner
// 
//  Created on 2/21/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import AppKit
import SwiftUI
import MetModel

/*
 *  Displays the section details for the exhibit reference data.
 */
struct EIVExhibitRefSectionView: View {
	let exhibit: MMExhibitRef
	
    var body: some View {
		EIVInspectorSectionGrid(sectionTitle: "Reference Item") {
			if let title = exhibit.title {
				EIVInspectorGridRow("Title", title)
			}
			if let name = exhibit.objectName, name.lowercased() != exhibit.title?.lowercased() {
				EIVInspectorGridRow("Name", name)
			}
			EIVInspectorGridRow("Department", exhibit.department)
			if let culture = exhibit.culture {
				EIVInspectorGridRow("Culture", culture)
			}
			
			if let medium = exhibit.medium {
				EIVInspectorGridRow("Medium", medium)
			}
			
			if !exhibit.tags.isEmpty {
				EIVInspectorGridRow("Tags", exhibit.tags.joined(separator: ", ").lowercased())
			}
						
			EIVInspectorGridRow("Created", exhibit.objectCreationDates)
			EIVInspectorGridRow("ObjectID", "\(exhibit.objectID)") {
				HStack {					
					ExhibitButton(exhibit: exhibit, systemName: "doc.on.doc") { exhibit in
						NSPasteboard.general.clearContents()
						NSPasteboard.general.setString("\(exhibit.objectID)", forType: .string)
					}

					ExhibitLinkButton(exhibit)
						.foregroundStyle(.selectionColor)
				}
			}
			if let aYear = exhibit.accessionYear {
				EIVInspectorGridRow("Acquired", "\(aYear)")
			}
			EIVInspectorGridRow("Accession Number", "\(exhibit.accessionNumber)")
			EIVInspectorGridRow("Highlighted", exhibit.isHighlight)
			EIVInspectorGridRow("Timeline Work", exhibit.isTimelineWork)
			EIVInspectorGridRow("Public Domain", exhibit.isPublicDomain)

			if let artist = exhibit.artistDisplayNameNormalized {
				EIVInspectorGridRow("Artist", artist)
				
				if let aristBio = exhibit.artistDisplayBioNormalized {
					EIVInspectorGridRow("Artist Bio", aristBio)
				}
			}
		}
    }
}

 #Preview {
	// ..preview with a wrapping title, artist, bio
	EIVExhibitRefSectionView(exhibit: MetModel.samplingIndex[0]!)
		.frame(width: 250, height: 400)
}
