//
//  ExhibitLinkButton.swift
//  MetDesigner
// 
//  Created on 2/22/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays a hyperlink item for an exhibit to open Safari with details.
 */
struct ExhibitLinkButton: View {
	let exhibit: MMExhibitRef
	
	init(_ exhibit: MMExhibitRef) {
		self.exhibit 	= exhibit
	}
		
    var body: some View {
		ExhibitButton(exhibit: exhibit, systemName: "arrow.up.right.circle.fill") { exhibit in
			guard let url = URL(string: exhibit.linkResource) else { return }
			NSWorkspace.shared.open(url)
		}
    }
}

#Preview {
	VStack {
		ExhibitLinkButton(MetModel.samplingIndex[2]!)
	}
	.frame(width: 100, height: 100)
}
