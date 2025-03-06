//
//  ExhibitButton.swift
//  MetDesigner
// 
//  Created on 2/24/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays a simple image button for an exhibit reference.
 */
struct ExhibitButton: View {
	let exhibit: MMExhibitRef
	let systemName: String
	typealias ActionBlock = (_ exhibit: MMExhibitRef) -> Void
	let action: ActionBlock
	
    var body: some View {
		Button(action: {
			action(exhibit)
		}, label: {
			Image(systemName: systemName)
		})
		.frame(height: 20)
		.buttonStyle(.plain)
    }
}

#Preview {
	VStack {
		ExhibitButton(exhibit: MetModel.samplingIndex[1]!, systemName: "face.smiling.inverse") { exhibit in
			// n/a
		}
	}
	.frame(width: 200, height: 200)
}
