//
//  ESVSearchListView.swift
//  MetDesigner
// 
//  Created on 2/9/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays a list of items displaying the currently applied search filter.
 */
struct ESVSearchListView: View {
	@Bindable private var userState: MDUserState
	@Binding private var exhibitList: MMExhibitCollection
	@FocusState private var isFocused: Bool
	
	init(userState: MDUserState, exhibitList: Binding<MMExhibitCollection>) {
		self._userState   = .init(userState)
		self._exhibitList = exhibitList
		self.isFocused    = (userState.selectionState?.asExhibitRefID != nil)
	}
		
    var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				LazyVStack(spacing: 0) {
					ForEach(self.exhibitList) { li in
						ESVSearchListCellView(li, isSelected: userState.selectionState?.asExhibitRefID == li.objectID)
							.id(li.objectID)
							.onTapGesture {
								userState.selectionState = .exhibitReference(li.objectID)
							}
					}
				}
				.background(.white)
				.focusable()
				.focused($isFocused)
				.focusEffectDisabled()
				.onKeyPress(.upArrow, action: {
					guard let rowIndex = self.currentRowIndex else { return .ignored }
					self.selectRow(index: rowIndex - 1, proxy: proxy)
					return .handled
				})
				.onKeyPress(.downArrow) {
					guard let rowIndex = self.currentRowIndex else { return .ignored }
					self.selectRow(index: rowIndex + 1, proxy: proxy)
					return .handled
				}
				.onTapGesture {
					isFocused = true
				}
				.onChange(of: exhibitList, { _, _ in
					guard let rowIndex = self.currentRowIndex else { return }
					self.selectRow(index: rowIndex, proxy: proxy)
				})
			}
			.background(.white)
		}
    }
	
	// - the row offset in the list.
	private var currentRowIndex: Int? {
		guard let selItem = userState.selectionState?.asExhibitRefID else { return nil }
		return self.exhibitList.firstIndex(where: {$0.objectID == selItem})
	}
	
	/*
	 *  Change the index of the selected row.
	 */
	private func selectRow(index newIndex: Int, proxy: ScrollViewProxy) {
		guard exhibitList.count > 0 else { return }
		let validIndex = min(max(newIndex, 0), exhibitList.count - 1)
		let eRef 	   = self.exhibitList[validIndex].objectID
		userState.selectionState = .exhibitReference(eRef)
		proxy.scrollTo(eRef)
	}
}

#Preview {
	let document = MetDesignerDocument()
	return ESVSearchListView(userState: document.userState,
							 exhibitList: .constant(.samplingIndex))
}
