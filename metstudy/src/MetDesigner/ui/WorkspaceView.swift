//
//  WorkspaceView.swift
//  MetDesigner
// 
//  Created on 1/27/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  The workspace is the primary designer interface that is composed
 *  of a series of split columns with navigator, editor and property
 *  inspector regions.
 */
struct WorkspaceView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var isShowingInspector: Bool = true
	
	// - the inspector doesn't respect the `ideal` width attribute when being 
	//   first displayed, which prevents the application of saved width defaults, so
	//   this allows us to apply a temporary width until that occurs.
	@State private var hasInspectorAppeared: Bool = false
	
	static let SideBarMaximumWidth: CGFloat = 300
	static var SideBarIdealWidth: CGFloat { (Self.SideBarMaximumWidth * 0.80).rounded() }
	
	/*
	 *  DESIGN: The split sections below must not set a maximum size in their .frame
	 * 	  	    modifiers or it will override the default widths assigned to them.
	 */
    var body: some View {
		NavigationSplitView {
			NavigatorView()
				.navigationSplitViewColumnWidth(min: 200, ideal: Self.SideBarIdealWidth, max: Self.SideBarMaximumWidth)
				.background(.thinMaterial)
		} detail: {
			EditorView()
				.inspector(isPresented: $isShowingInspector) {
					InspectorView(userState: document.userState)
						.inspectorColumnWidth(min: 200, ideal: self.inspectorIdealWidth, max: 350)
						.interactiveDismissDisabled()
						.frame(minWidth: hasInspectorAppeared ? nil : self.inspectorIdealWidth)
						.onAppear(perform: {
							hasInspectorAppeared = true
						})

				}
		}
    }
	
	// - the preferred initial width of the inspector when displaying the view.
	private var inspectorIdealWidth: CGFloat {
		document.userState.inspectorWidth ?? WorkspaceView.SideBarIdealWidth
	}
}

#Preview {
    WorkspaceView()
		.frame(width: 1024, height: 768)
}
