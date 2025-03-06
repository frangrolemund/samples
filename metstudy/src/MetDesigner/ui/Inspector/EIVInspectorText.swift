//
//  EIVInspectorText.swift
//  MetDesigner
// 
//  Created on 2/22/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays textual read-only data in the inspector.
 */
struct EIVInspectorText: View {
	private let text: String
	private let isCode: Bool
	
	init(_ text: String?) {
		self.text   = text ?? String(localized: "n/a")
		self.isCode = text == nil
	}
	
	init(_ flag: Bool) {
		self.text   = flag ? String(localized: "YES") : String(localized: "NO")
		self.isCode = true
	}

    var body: some View {
		if isCode {
			Text(verbatim: text)
				.font(.callout)
				.foregroundStyle(.black)
		}
		else {
			Text(verbatim: text)
				.foregroundStyle(.black)
				.fontWeight(.medium)
		}
    }
}

#Preview {
	VStack(spacing: 10) {
		EIVInspectorText("Jerimiah Whitley")
		EIVInspectorText("505 Rainbow Terrace")
		EIVInspectorText("Planes, Trains, Automobiles")
		EIVInspectorText(nil)
		EIVInspectorText(true)
		EIVInspectorText(false)
	}
	.frame(maxWidth: 250)
}
