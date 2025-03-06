//
//  EIVExhibitSectionView.swift
//  MetDesigner
// 
//  Created on 2/27/24
//  Copyright © 2024 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  Displays an official (downloaded) exhibit instance.
 */
struct EIVExhibitSectionView: View {
	@Bindable private var exhibit: MMExhibit
	private let isReadOnly: Bool
	@State private var photos: Photos?
	@State private var isExporting: Bool = false
	
	init(exhibit: MMExhibit, isReadOnly: Bool) {
		self._exhibit	= .init(exhibit)
		self.isReadOnly = isReadOnly
	}
	
    var body: some View {
		VStack(alignment: .leading) {
			EIVExhibitGridView {
				EIVInspectorGridRow("ObjectID", "\(exhibit.objectID)")
			}
			
			
			Button {
				isExporting = true
			} label: {
				Text("Export")
			}
			.disabled(photos?.primary?.data == nil)
			.fileExporter(isPresented: $isExporting, item: photos?.primary?.data, defaultFilename: defaultExportFileName) { result in
				if case .failure(let error) = result {
					MDLog.error("Failed to export the photo.  \(error.localizedDescription)")
				}
			}
			
			if let sImg = self.photos?.small {
				sImg.asImage
					.resizable(resizingMode: .stretch)
					.aspectRatio(contentMode: .fit)
			}
		}
		.onAppear(perform: {
			self.updateExhibitResources()
		})
		.onChange(of: exhibit, { _, _ in
			self.updateExhibitResources()
		})
    }
}

/*
 *  Internal implementation.
 */
extension EIVExhibitSectionView {
	private struct Photos {
		var small: MMImageRef?
		var primary: MMImageRef?
		var additional: [MMImageRef]?
	}
	
	/*
	 *  Reload the exhibit resources because the exhibit has changed.
	 */
	private func updateExhibitResources() {
		self.photos = nil
		Task {
			self.photos = .init(small: await exhibit.primaryImageSmall)
			
			// ...the larger images will take a moment to retrieve so they can
			//	  be delayed
			let primary = await exhibit.primaryImage
			let other   = await exhibit.additionalImages
			self.photos = .init(small: self.photos?.small, primary: primary, additional: other)
		}
	}
	
	/*
	 *  The default name to use for exporting a photo.
	 */
	private var defaultExportFileName: String {
		var baseName = exhibit.title ?? exhibit.exhbitName ?? ""
		baseName     = baseName.replacingOccurrences(of: " ", with: "")
		return "\(baseName)-\(exhibit.objectID).jpg"
	}
}

#Preview {
	EIVExhibitSectionView(exhibit: MetModel.sampleExhibit, isReadOnly: true)
		.frame(width: 200, height: 300)
}
