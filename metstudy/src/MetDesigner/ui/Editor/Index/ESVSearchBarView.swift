//
//  ESVSearchBarView.swift
//  MetDesigner
// 
//  Created on 2/19/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays a region that provides search filtering capabilities.
 */
struct ESVSearchBarView: View {
	@Binding private var filter: MMFilterCriteria?
	private let showProgress: Bool
	@State private var isFilterExpanded: Bool
	private let exhibitCount: Int
	
	init(filter: Binding<MMFilterCriteria?>, showProgress: Bool, exhibitCount: Int) {
		self._filter 	  = filter
		self.showProgress = showProgress
		isFilterExpanded  = filter.wrappedValue?.requiresSpecializedDisplay ?? false
		self.exhibitCount = exhibitCount
	}
	
    var body: some View {
		VStack(spacing: 0) {
			HStack {
				ESVSearchFieldView(filter: $filter, showProgress: showProgress)
				
				Button("Reset Filter") {
					withAnimation {
						self.filter = nil
					}
				}
				.font(.caption)
				.buttonStyle(.link)
				.padding(.init(top: 0, leading: 0, bottom: 10, trailing: 0))
				.opacity((self.filter?.isFiltered ?? false) ? 1.0 : 0.0)
			}
			
			HStack {
				Image(systemName: "arrowtriangle.right.fill")
					.frame(width: 10, height: 10)
					.foregroundStyle(filter?.requiresSpecializedDisplay ?? false ? .gray : .black)
					.rotationEffect(.init(degrees: isFilterExpanded ? 90.0 : 0.0))
					.onTapGesture {
						guard !isFilterExpanded || !(filter?.requiresSpecializedDisplay ?? false) else { return }
						withAnimation(.easeOut) {
							isFilterExpanded.toggle()
						}
					}
			
				Spacer()
			}
			.padding(.init(top: 10, leading: 0, bottom: 0, trailing: 0))
			
			if isFilterExpanded {
				ESVSearchExpansionView(filter: $filter)
					.padding(.init(top: 10, leading: 0, bottom: 0, trailing: 0))
			}
			
			HStack {
				Spacer()
				if exhibitCount > 0 {
					Text(LocalizedStringKey("search.bar.exhibits.\(exhibitCount)"))
						.font(.caption2)
				}
			}
		}
		.padding(.init(top: 10, leading: 10, bottom: 4, trailing: 10))
		.background(.barBackground)
		.onChange(of: filter) { _, newValue in
			self.isFilterExpanded = filter?.requiresSpecializedDisplay ?? false
		}
    }
}

#Preview {
    ESVSearchBarView(filter: .constant(nil), showProgress: false, exhibitCount: 5)
}

/*
 *  Utilities.
 */
fileprivate extension MMFilterCriteria {
	// - default behavior for showing the filter or allowing it to be collapsed
	var requiresSpecializedDisplay: Bool {
		self.matchingRule != .andMatch || self.creationYear != nil
	}
}
