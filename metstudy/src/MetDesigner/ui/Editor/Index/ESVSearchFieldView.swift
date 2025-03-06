//
//  ESVSearchFieldView.swift
//  MetDesigner
// 
//  Created on 2/9/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays a custom searching text field.
 */
struct ESVSearchFieldView: View {
	@Binding private var filter: MMFilterCriteria?
	private let showProgress: Bool
	@State private var searchText: String = ""
	@FocusState private var isFocused: Bool
	
	init(filter: Binding<MMFilterCriteria?>, showProgress: Bool) {
		self._filter 	  = filter
		self.showProgress = showProgress
	}
	
    var body: some View {
		HStack(spacing: 0) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.gray)
			
			TextField("Search for exhibits..", text: $searchText)
				.textFieldStyle(.plain)	// - required to not show a focus border (.focusEffectDisabled doesn't work here)
				.padding(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
				.onTapGesture {
					isFocused = true
				}
				.onChange(of: searchText, { oldValue, newValue in
					self.filter = (self.filter ?? .init()).withSearchText(newValue)
				})
				.onChange(of: filter, { _, newValue in
					self.searchText = newValue?.searchText ?? ""
				})
				.onSubmit {
					isFocused = false	// - discard focus when hitting enter
				}
			
			MDCircularProgressView()
				.opacity(showProgress ? 1.0 : 0.0)
		}
		.font(.title3)
		.padding(.init(top: 5, leading: 10, bottom: 5, trailing: 10))
		.focused($isFocused)
		.background(.white)
		.clipShape(RoundedRectangle(cornerRadius: 15))
		.overlay(content: {
			RoundedRectangle(cornerRadius: 10)
				.strokeBorder(style: .init(lineWidth: 1))
				.foregroundStyle(.gray)
		})
		.onAppear(perform: {
			// - to disable in initial focus
			Task { isFocused = false }
		})
    }
}

#Preview {
	ESVSearchFieldView(filter: .constant(nil), showProgress: true)
}
