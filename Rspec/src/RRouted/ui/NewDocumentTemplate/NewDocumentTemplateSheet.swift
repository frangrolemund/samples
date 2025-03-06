//
//  NewDocumentTemplateSheet.swift
//  RRouted
// 
//  Created on 9/21/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  This view is displayed when creating a new document to give
 *  the user convenient ways of auto-configuring the initial behavior.
 */
struct NewDocumentTemplateSheet: View {
	@EnvironmentObject private var document: RRoutedDocument
	@Binding private var isSheetVisible: Bool
	
	/*
	 *  Initialize the sheet.
	 */
	init(withSheetVisible isSheetVisible:Binding<Bool>) {
		self._isSheetVisible = isSheetVisible
	}
	
    var body: some View {
		VStack {
			Text("Choose a Template").font(.title).bold()
				.frame(alignment: .center)
				.padding()
			Spacer()
			HStack {
				Button("Blank Document") {
					dismiss()
				}
				Button("Standard 3 Port") {
					document.engine.debugAddHTTPPort()
					document.engine.debugAddHTTPPort()
					document.engine.debugAddHTTPPort()
					dismiss()
				}
			}
			.padding()
			Spacer()
		}
		.background(.white)
    }
}

/*
 *  Internal.
 */
extension NewDocumentTemplateSheet {
	/*
	 *  Dismiss the sheet.
	 */
	private func dismiss() {
		self.isSheetVisible = false
	}
}

/*
 * Preview for the sheet.
 */
#Preview {
	NewDocumentTemplateSheet(withSheetVisible: .constant(true))
		.environmentObject(RRoutedDocument())
}
