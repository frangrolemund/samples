//
//  InspectorView.swift
//  MetDesigner
// 
//  Created on 1/31/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  The inspector provides a way to view and optionally edit selected items
 *  from the navigator or editor.
 */
struct InspectorView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var userState: MDUserState
	
	/*
	 *  Initialize the object.
	 */
	init(userState: MDUserState) {
		self.userState = userState
	}
		
	/*
	 * Inspector layout.
	 */
    var body: some View {
		VStack(spacing: 0) {
			if let eId = userState.selectionState?.asExhibitRefID,
			   let eRef = document.objectIndex?.object(byID: eId) {
				ExhibitRefInspectorView(eRef: eRef)
			}
		}
		.background(.windowBackground)
		.onSizeChange { size in
			document.userState.inspectorWidth = size.width
		}
    }
}
