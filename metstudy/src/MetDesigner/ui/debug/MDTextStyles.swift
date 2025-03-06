//
//  MDTextStyles.swift
//  MetDesigner
// 
//  Created on 2/8/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

//  DEBUG: A quick way to see the sizes of the standard text fonts.
struct MDTextStyles: View {
    var body: some View {
		VStack(spacing: 20) {
			MDSampleText(.largeTitle, named: ".largeTitle")
			MDSampleText(.title, named: ".title")
			MDSampleText(.title2, named: ".title2")
			MDSampleText(.title3, named: ".title3")
			MDSampleText(.headline, named: ".headline")
			MDSampleText(.subheadline, named: ".subheadline")
			MDSampleText(.body, named: ".body")
			MDSampleText(.callout, named: ".callout")
			MDSampleText(.caption, named: ".caption")
			MDSampleText(.caption2, named: ".caption2")
			MDSampleText(.footnote, named: ".footnote")
			
		}
    }
}

fileprivate struct MDSampleText : View {
	let font: Font
	let name: String
	
	init(_ font: Font, named: String) {
		self.font = font
		self.name = named
	}
	
	var body: some View {
		HStack {
			Text("\(name):").font(font).bold()
			Text("MetDesigner is a brand new experience.")
				.font(font)
		}
	}
}

#Preview {
    MDTextStyles()
}
