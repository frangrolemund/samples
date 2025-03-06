//
//  EditorView.swift
//  MetDesigner
// 
//  Created on 1/31/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  The editor is used to build curated tours from the available data.
 */
struct EditorView: View {
    var body: some View {
		VSplitView(content: {
			ExhibitIndexView()
				.frame(minHeight: 50)
			
			TourDesignerView()
				.frame(minHeight: 50)
		})
    }
}

#Preview {
    EditorView()
}
