//
//  ESVSearchExpansionView.swift
//  MetDesigner
// 
//  Created on 2/19/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays expanded search options for the exibhit list.
 */
struct ESVSearchExpansionView: View {
	@Binding private var filter: MMFilterCriteria?
	@State private var matchingRule: MMFilterCriteria.MatchingRule
	@State private var creationYear: Int?
	
	init(filter: Binding<MMFilterCriteria?>) {
		self._filter  	   = filter
		self._matchingRule = .init(initialValue: filter.wrappedValue?.matchingRule ?? .andMatch)
		self._creationYear = .init(initialValue: filter.wrappedValue?.creationYear)
	}
	
    var body: some View {
		HStack {
			Grid(alignment: .leading) {
				GridRow {
					Text("Matching:").fontWeight(.medium)
					
					HStack {
						Picker(selection: $matchingRule) {
							Text("ALL keywords").tag(MMFilterCriteria.MatchingRule.andMatch)
							Text("Any keyword").tag(MMFilterCriteria.MatchingRule.orMatch)
						} label: {
							EmptyView()
						}
						.frame(maxWidth: 200)
						
						Spacer()
					}
				}
				
				GridRow {
					Text("Year Created:").fontWeight(.medium)
					
					HStack {
						TextField(value: $creationYear, format: .number.grouping(.never)) {
							EmptyView()
						}
						.frame(maxWidth: 65)
						.focusEffectDisabled()

						Spacer()
					}
				}
			}
			
			Spacer()
		}
		.onChange(of: filter, { _, newValue in
			self.matchingRule = filter?.matchingRule ?? .andMatch
			self.creationYear = filter?.creationYear
		})
		.onChange(of: matchingRule) { oldValue, newValue in
			self.filter = (self.filter ?? .init()).withMatchingRule(newValue)
		}
		.onChange(of: creationYear) { oldValue, newValue in
			self.filter = (self.filter ?? .init()).withCreationYear(newValue)
		}
    }
}

#Preview {
	ESVSearchExpansionView(filter: .constant(nil))
}
