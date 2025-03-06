//
//  ExhibitIndexView.swift
//  MetDesigner
// 
//  Created on 1/31/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a search experience into the exhibit index.
 */
struct ExhibitIndexView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var hasAppeared: Bool = false
	
    var body: some View {
		ExhibitFilteringListView(userState: document.userState)
			.onAppear(perform: {
				hasAppeared = true
			})
			.onSizeChange { size in
				document.userState.indexSearchHeight = size.height
			}
			.frame(height: hasAppeared ? nil : document.userState.indexSearchHeight)
    }
}

#Preview {
    ExhibitIndexView()
		.environmentObject(MetDesignerDocument())
		.frame(width: 600, height: 250)
}
