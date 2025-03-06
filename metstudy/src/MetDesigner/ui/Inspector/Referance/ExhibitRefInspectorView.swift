//
//  ExhibitRefInspectorView.swift
//  MetDesigner
// 
//  Created on 2/21/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays a single exhibit reference from the index in the inspector.
 *  NOTE:  This also displays the actual exhibit as well when it is retrieved so
 *  	   that we have the 'official' content to consult also.
 */
struct ExhibitRefInspectorView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	let eRef: MMExhibitRef
	@State private var exhibit: ExhibitInfo = .pending
	
	private enum ExhibitInfo : Equatable {
		case pending
		case none
		case exhibit(_ value: MMExhibit)
		
		static func fromExhibit(_ value: MMExhibit?) -> ExhibitInfo {
			if let value = value {
				return .exhibit(value)
			}
			else {
				return none
			}
		}
	}
	
	/*
	 *  Initialize the object.
	 */
	init(eRef: MMExhibitRef) {
		self.eRef = eRef
	}
	
	/*
	 *  Lay out the content.
	 */
    var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				EIVExhibitRefSectionView(exhibit: eRef)
				
				Divider()
					.padding(.init(top: 0, leading: 0, bottom: 10, trailing: 0))
				
				// - includes the exhibit data when available, but keep in mind
				//   that since the exhibit itself is state, it could be saved from
				//   the last instance of this view, so we need to check for matching
				//   ids.
				if case .exhibit(let eValue) = exhibit, eValue.objectID == eRef.objectID {
					EIVExhibitSectionView(exhibit: eValue, isReadOnly: true)
				} else {
					EIVExhibitGridView {
						if exhibit == .none {
							Text("No data found.")
								.foregroundStyle(.gray)
						}
						else {
							HStack(alignment: .center) {
								Spacer()
								MDCircularProgressView()
								Spacer()
							}
						}
					}
				}
				
				Spacer()
			}
			.padding()
			.task(id: eRef) {
				self.exhibit = .pending
				let eItem 	 = try? await document.objectIndex?.exhibit(from: self.eRef).get()
				let _     	 = await eItem?.primaryImageSmall
				self.exhibit = .fromExhibit(eItem)
			}
		}
    }
}

#Preview {
	ExhibitRefInspectorView(eRef: MetModel.samplingIndex[0]!)
		.environmentObject(MetDesignerDocument())
		.frame(width: 250, height: 700)
}
