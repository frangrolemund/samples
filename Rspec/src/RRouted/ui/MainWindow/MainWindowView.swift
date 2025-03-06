//
//  MainWindowView.swift
//  RRouted
// 
//  Created on 9/19/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  The main window provides the structure of the IDE in a design
 *  intentionally famiilar to Xcode users.
 */
struct MainWindowView: View {
	@EnvironmentObject var document: RRoutedDocument
	@State private var isNewDocumentSheetVisible: Bool = false

    var body: some View {
		GeometryReader(content: { geometry in
			NavigationSplitView {
				NavigatorView()
					.navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 300)
			} detail: {
				EditorView()
			}
			.onAppear(perform: {
				self.viewDidAppear()
			})
			.sheet(isPresented: $isNewDocumentSheetVisible, content: {
				NewDocumentTemplateSheet(withSheetVisible: $isNewDocumentSheetVisible)
					.frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.8)
			})
		})
		.onDisappear(perform: {
			document.close()
		})
    }
}

/*
 *  Internal implementation.
 */
extension MainWindowView {
	/*
	 *  The view has appeared.
	 */
	private func viewDidAppear() {
		// - configure the document
		if document.isNewDocument {
			Task {
				try? await Task.sleep(for: .milliseconds(300))
				self.isNewDocumentSheetVisible = true
			}
		}
	}
}
