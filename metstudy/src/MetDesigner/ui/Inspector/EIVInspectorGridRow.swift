//
//  EIVInspectorGridRow.swift
//  MetDesigner
// 
//  Created on 2/22/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a row of data in an inspector section.
 */
struct EIVInspectorGridRow<Content: View> : View {
	private let label: LocalizedStringKey
	private let value: Format
	private let content: ContentBuilder
	
	typealias ContentBuilder = () -> Content
	init(_ label: LocalizedStringKey, _ text: String?, @ViewBuilder content: @escaping ContentBuilder = { EmptyView() }) {
		self.label 	 = label
		self.value 	 = .text(text)
		self.content = content
	}
	
	init(_ label: LocalizedStringKey, _ flag: Bool, @ViewBuilder content: @escaping ContentBuilder = { EmptyView() }) {
		self.label 	 = label
		self.value 	 = .flag(flag)
		self.content = content
	}

    var body: some View {
		GridRow {
			EIVInspectorLabel(label)
				.gridColumnAlignment(.trailing)
			
			HStack(alignment: .center) {
				switch value {
				case .text(let tVal):
					EIVInspectorText(tVal)
						.gridColumnAlignment(.leading)

				case .flag(let fVal):
					EIVInspectorText(fVal)
						.gridColumnAlignment(.leading)
				}
				
				// - optional trailing content
				content()
			}
				.gridColumnAlignment(.leading)
		}
    }
	
	// - internal
	private enum Format {
		case text(_ value: String?)
		case flag(_ value: Bool)
	}
}

#Preview {
	Grid {
		EIVInspectorGridRow("Artist", "Jerimiah Whitley")
		EIVInspectorGridRow("Culture", "American")
		EIVInspectorGridRow("Title", "Planes, Trains, Automobiles")
		EIVInspectorGridRow("Artist Bio", nil)
		EIVInspectorGridRow("Highlighted", true)
	}
}
