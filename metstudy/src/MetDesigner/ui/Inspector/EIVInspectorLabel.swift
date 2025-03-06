//
//  EIVInspectorLabel.swift
//  MetDesigner
// 
//  Created on 2/22/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a descriptive element in the inspector.
 */
struct EIVInspectorLabel: View {
	let text: LocalizedStringKey
	
	init(_ text: LocalizedStringKey) {
		self.text = text
	}
	
    var body: some View {
		HStack(alignment: .bottom, spacing: 0) {
			Text(text)
				.multilineTextAlignment(.trailing)
			Text(verbatim: ":")
		}
		.font(.subheadline)
		.foregroundStyle(.black)
    }
}

#Preview {
	VStack(spacing: 10) {
		EIVInspectorLabel("Department")
		EIVInspectorLabel("Title")
		EIVInspectorLabel("Culture")
	}
	.frame(width: 200, height: 400)
}
