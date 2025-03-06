//
//  ESVSearchListCellView.swift
//  MetDesigner
// 
//  Created on 2/17/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import AppKit
import SwiftUI
import MetModel

/*
 *  Displays a single exhibit.
 */
struct ESVSearchListCellView: View {
	let exhibit: MMExhibitRef
	let isSelected: Bool
	
	init(_ exhibit: MMExhibitRef, isSelected: Bool) {
		self.exhibit 	= exhibit
		self.isSelected = isSelected
	}
	
    var body: some View {
		Group {
			VStack(spacing: 0) {
				// - top row
				HStack {
					Text(exhibitName)
						.font(.body)
						.bold()
						.layoutPriority(1)
					
					ExhibitLinkButton(exhibit)
						.foregroundStyle(!isSelected ? .selectionColor : .white)
						.layoutPriority(2)
					
					HStack {
						Text(exhibit.tags.joined(separator: ", "))
							.font(.caption2)
							.lineLimit(1)
						Spacer()
					}
					.frame(minWidth: 150)
					
					Spacer()
					
					Text(exhibit.objectCreationDates)
						.font(.body)
						.bold()
						.layoutPriority(1)
				}
				
				// - detail row
				HStack(spacing: 0) {
					Text(exhibit.department)
						.font(.subheadline)
					if let eDesc = exhibitDescription {
						Text(" - \(eDesc)")
							.font(.subheadline)
							.foregroundStyle(isSelected ? .white : .gray)
					}
					Spacer()
				}
			}
			.padding(.init(top: 5, leading: 10, bottom: 5, trailing: 10))
		}
		.overlay(content: {
			VStack {
				Spacer()
				if !isSelected {
					Color.lightGray
						.padding(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
						.frame(height: 1)
				}
			}
		})
		.background(isSelected ? .selectionColor : .white)
		.foregroundStyle(textColor)
		.frame(maxWidth: .infinity)
		.frame(height: 45)
    }

	// - compute a human-readable name for the exhibit.
	private var exhibitName: String {
		if let eName = exhibit.objectName, let eTitle = exhibit.title, !eName.localizedCaseInsensitiveContains(eTitle), !eTitle.localizedCaseInsensitiveContains(eName) {
			return "\(eTitle) - \(eName)"
		}
		else {
			return exhibit.title ?? exhibit.objectName ?? "N/A"
		}
	}
	
	// - compute description text to display for the exhibit.
	private var exhibitDescription: String? { exhibit.medium }
	
	// - compute the right text color.
	private var textColor: Color { isSelected ? .white : .black}
}

#Preview {
	VStack(spacing: 0) {
		ESVSearchListCellView(.init(objectID: 4, accessionNumber: "44-5531-33", isHighlight: true, isTimelineWork: false, isPublicDomain: true, department: "American History", accessionYear: 1980, objectName: "Revolutionary Musket", title: "Gun", culture: "American", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1774, objectEndDate: 1774, medium: "Iron", linkResource: "http://apple.com", tags: ["gun", "independence", "war"]), isSelected: false)
		
		ESVSearchListCellView(.init(objectID: 4, accessionNumber: "44-5531-34", isHighlight: true, isTimelineWork: false, isPublicDomain: true, department: "American History", accessionYear: 1977, objectName: nil, title: "Bonnet", culture: "American", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1774, objectEndDate: 1774, medium: "Cotten", linkResource: "http://apple.com", tags: ["clothing"]), isSelected: false)
		
		ESVSearchListCellView(.init(objectID: 4, accessionNumber: "44-5531-35", isHighlight: true, isTimelineWork: false, isPublicDomain: true, department: "American History", accessionYear: 1980, objectName: "Wooden Bucket", title: nil, culture: "American", artistDisplayName: nil, artistDisplayBio: nil, objectBeginDate: 1775, objectEndDate: 1775, medium: "Wood", linkResource: "http://apple.com", tags: []), isSelected: false)
	}
	.frame(width: 550)
}
