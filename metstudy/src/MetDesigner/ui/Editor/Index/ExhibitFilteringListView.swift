//
//  ExhibitFilteringListView.swift
//  MetDesigner
// 
//  Created on 2/9/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Presents the index as a searchable list of items.
 */
struct ExhibitFilteringListView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@State private var userState: MDUserState
	@State private var filter: MMFilterCriteria?
	@State private var exhibitList: MMExhibitCollection = .default
	@State private var pendingFilter: Task<Void, Never>?
	@State private var pendingTasks: Int = 0
	@State private var alert: MDAlertInfo = .none
	
	init(userState: MDUserState) {
		self.userState = userState
	}
	
    var body: some View {
		VStack(spacing: 1) {
			ESVSearchBarView(filter: $filter, showProgress: pendingTasks > 0, exhibitCount: exhibitList.count)
			
			if !exhibitList.isEmpty {
				ESVSearchListView(userState: userState, exhibitList: $exhibitList)
			}
			else {
				VStack {
					Spacer()
					HStack {
						Spacer()
						Text("No exhibits found.")
							.font(.body)
							.foregroundStyle(.gray)
						Spacer()
					}
					Spacer()
				}
				.background(.white)
			}
		}
		.background(.gray)
		.onAppear {
			// ...the current result of filtering depends on the
			//    document, which isn't available until after init()
			self.filter = userState.filterContext?.criteria
			
			// ...the saved context omits the cost of applying it.
			self.reapplyActiveFilter(withContext: userState.filterContext)
		}
		.onChange(of: filter) { oldValue, newValue in
			self.reapplyActiveFilter()
		}
    }
}

/*
 *  Internal implementation.
 */
extension ExhibitFilteringListView {
	/*
	 *  Filter the contents of the exchibit index.
	 */
	private func reapplyActiveFilter(withContext context: MMFilterContext? = nil) {
		pendingTasks += 1
		pendingFilter?.cancel()
		pendingFilter = Task {
			if let objectIndex = self.document.objectIndex {
				do {
					let ret: MMExhibitCollection
					if let context = context {
						ret = try await objectIndex.filtered(using: context)
					}
					else  {
						ret = try await objectIndex.filtered(by: filter)
					}
					
					// - only successful results are displayed, nothing partial.
					if !Task.isCancelled {
						self.exhibitList 			 = ret
						self.userState.filterContext = ret.context
						
						// ...if the selected item no longer applies, reset it.
						if let ssObj = self.userState.selectionState?.asExhibitRefID,  ret.firstIndex(where: {$0.objectID == ssObj}) == nil {
							self.userState.selectionState = nil
						}
					}
				}
				catch {
					MDLog.error("The exhibit index failed to be filtered successfully.  \(error.localizedDescription)")
					self.alert = .init(error: error)
				}
			}
			
			// - progress is keyed off of the number of tasks.
			self.pendingTasks -= 1
		}
	}
}

#Preview {
	let document = MetDesignerDocument()
	return ExhibitFilteringListView(userState: document.userState)
		.frame(width: 550)
		.environmentObject(document)
}
