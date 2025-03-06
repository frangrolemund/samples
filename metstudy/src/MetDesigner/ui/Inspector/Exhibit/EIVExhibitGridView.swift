//
//  EIVExhibitGridView.swift
//  MetDesigner
// 
//  Created on 3/2/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 * Disisplays an inspector section for exhibit data.
 */
struct EIVExhibitGridView<Content: View> : View {
	let content: () -> Content
	
	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}
	
	var body: some View {
		EIVInspectorSectionGrid(sectionTitle: "Exhibit", content: content)
	}
}
