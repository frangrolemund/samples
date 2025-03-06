//
//  EIVInspectorSectionGrid.swift
//  MetDesigner
// 
//  Created on 2/22/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a section of data in the
 */
struct EIVInspectorSectionGrid<Content: View> : View {
	let sectionTitle: LocalizedStringKey
	let content: () -> Content
	
	init(sectionTitle: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
		self.sectionTitle = sectionTitle
		self.content      = content
	}
	
	var body: some View {
		VStack {
			EIVInspectorSectionLabel(sectionTitle)
			
			HStack {
				// - NOTE: the verticalSpacing will constrain the vertical
				//	 height of each row, preventing the wrapping we want to
				//   see in the grid items, so it is not applied here.
				Grid {
					content()
				}
				.padding(.init(top: 0, leading: 5, bottom: 0, trailing: 0))
				Spacer()
			}
		}
	}
}

#Preview {
	EIVInspectorSectionGrid(sectionTitle: "Exhibit Reference") {
		EIVInspectorGridRow("Artist", "Sandra Collins")
		EIVInspectorGridRow("Culture", "Britsh")
		EIVInspectorGridRow("Name", "Still water by a farmhouse.")
	}
}
