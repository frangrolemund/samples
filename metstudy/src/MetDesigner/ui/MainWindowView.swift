//
//  MainWindowView.swift
//  MetDesigner
// 
//  Created on 1/27/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI

/*
 *  Implements a single instance of a document window.
 *  DESIGN: Its purpose is to swap between a convenient interface
 * 			for initailly importing an object index and one for
 *			designing tours.
 */
struct MainWindowView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var didAppear: Bool = false
	
	/*
	 *  DESIGN:  In order to persist the document size so it can be defaulted
	 *  		 on opening, the view reports its size and saves it to a
	 *			 location in the filesystem outside the document but identified
	 *  		 by it and uses that information one time during startup to
	 * 	 		 set a default size. The individual panes in the window separated
	 * 	 		 by splitters use a similar approach.
	 */
    var body: some View {
		Group {
			if document.isIndexed {
				WorkspaceView()
			}
			else {
				IndexImportView()
			}
		}
		.onAppear(perform: {
			didAppear = true
		})
		.onSizeChange { size in
			document.userState.windowSize = size
		}
		.frame(width: didAppear ? nil : document.userState.windowSize.width, height: didAppear ? nil : document.userState.windowSize.height)
    }
}

