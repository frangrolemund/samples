//
//  EIVInspectorSectionLabel.swift
//  MetDesigner
// 
//  Created on 2/22/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a section title.
 */
struct EIVInspectorSectionLabel: View {
	let text: LocalizedStringKey
	
	init(_ text: LocalizedStringKey) {
		self.text = text
	}
	
    var body: some View {
		HStack {
			Text(text)
				.font(.body)
				.fontWeight(.medium)
				.foregroundStyle(.darkGray)
				.padding(.init(top: 0, leading: 0, bottom: 5, trailing: 0))
			
			Spacer()
		}
        
    }
}

#Preview {
	VStack {
		EIVInspectorSectionLabel("Exhibit Reference")
	}
}
