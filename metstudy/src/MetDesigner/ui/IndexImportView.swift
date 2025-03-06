//
//  IndexImportView.swift
//  MetDesigner
// 
//  Created on 1/27/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import SwiftUI
import MetModel

/*
 *  The index import view is used to 
 */
struct IndexImportView: View {
	@EnvironmentObject private var document: MetDesignerDocument
	@Environment(\.undoManager) private var undoManager
	@State private var doImport: Bool	  = false
	@State private var isImporting: Bool {
		didSet {
			// ...set from the progress callback
			isStarted    = false
			lineCount    = 0
			totalCount   = 0
			isOptimizing = false
		}
	}
	@State private var isStarted: Bool
	@State private var isOptimizing: Bool
	@State private var lineCount: Int
	@State private var totalCount: Int
	@State private var isDropping: Bool	  = false
	@State private var alert: MDAlertInfo = .none
	
	/*
	 *  Initialize the object.
	 */
	init() {
		self.isImporting  = false
		self.isStarted	  = false
		self.isOptimizing = false
		self.lineCount	  = 0
		self.totalCount	  = 0
	}
	
	/*
	 *  Internal initializer to assist with debugging
	 */
	fileprivate init(isImporting: Bool, isStarted: Bool, isOptimizing: Bool, lineCount: Int, totalCount: Int) {
		self.isImporting  = isImporting
		self.isStarted	  = isStarted
		self.isOptimizing = isOptimizing
		self.lineCount	  = lineCount
		self.totalCount   = totalCount
	}
	
	private static let ButtonWidth: CGFloat = 150
    var body: some View {
		VStack(alignment: .center) {
			Color.clear.frame(height: 100)
			
			VStack(spacing: 10) {
				// - copy
				Text(String(localized: "Import MetArt Exhibits", comment: "Title of initial state in document directing the user to import dependent data.")).font(.title)
				
				HStack {
					VStack(alignment: .leading, spacing: 15) {
						Text(subTitle)
							.font(.title3)
							.foregroundStyle(.secondary)

						Text(tapDirection)
							.font(.title3)
							.foregroundStyle(.secondary)
					}
					Spacer()
				}
				.padding(.init(top: 0, leading: 0, bottom: 15, trailing: 0))
				
				// - import button
				ImportButton(isSelected: isDropping, isEnabled: !isImporting && !document.isIndexed) {
					doImport = true
				}
				.frame(width: Self.ButtonWidth, height: Self.ButtonWidth)
				.fileImporter(isPresented: $doImport, allowedContentTypes: [.commaSeparatedText]) { result in
					switch result {
					case .success(let url):
						self.importIndex(from: url)
						
					case .failure(let err):
						self.alert = .init(error: err)
					}
				}
				.dropDestination(for: URL.self, action: { items, location in
					guard let url = items.first, url.pathExtension == "csv" else { return false }
					self.importIndex(from: url)
					return true
				}, isTargeted: {
					self.isDropping = $0
				})
				.overlay(alignment: .top) {
					if isImporting {
						self.statusView
							.offset(.init(width: 0, height: Self.ButtonWidth + 10))
					}
					else {
						EmptyView()
					}
				}
				.errorAlert(with: $alert)
			}
			.frame(width: 350)
			Spacer()
		}
	}
}

/*
 * Internal implementation.
 */
extension IndexImportView {
	/*
	 *  Generate the subtitle text.
	 */
	private var subTitle: AttributedString {
		try! .init(markdown: String(localized: "**MetDesigner** requires the [Metropolitan Museum of Art Open Access CSV](https://github.com/metmuseum/openaccess) as a reference in this document for the museum's public exhibits.", comment: "Descriptive markdown describing the external data required by the document."))
	}
	
	/*
	 *  Generate the text to give direction about how to use this screen.
	 */
	private var tapDirection: AttributedString {
		try! .init(markdown: String(localized: "Tap upon or drag the `MetObjects.csv` file onto the button below to get started.", comment: "Descriptive markdown directing the user how to begin importing data."))
	}
	
	/*
	 *  Manage the import processing.
	 */
	private func importIndex(from url: URL) {
		isImporting = true
		Task {
			do {
				let mi = try await MetModel.readIndex(from: url) { status in
					switch status {
					case .started(let total):
						self.isStarted  = true
						self.totalCount = total
					
					case .progress(let row, let total):
						self.lineCount  = row
						self.totalCount = total
						
					case .completed(_, _, let rate):
						self.lineCount = self.totalCount
						MDLog.info("The index was read at a rate of \(rate.formatted(.number.precision(.fractionLength(2)))) rps.")
						
					case .optimizing:
						self.isOptimizing = true
					}
				}
				
				self.document.saveObjectIndex(mi, undoManager: self.undoManager)
			}
			catch {
				self.alert = .init(error: error)
			}
			isImporting = false
		}
	}
	
	/*
	 *  Displays current progress under the button.
	 */
	private var statusView: some View {
		Group {
			if isStarted, !isOptimizing {
				VStack(spacing: 4) {
					Text(self.statusText)
					let progress = totalCount != 0 ? (Float(lineCount) / Float(totalCount)) : 0.0
					ProgressView(value: progress)
				}
			}
			else {
				HStack {
					Spacer()
					Text(self.statusText)
						.overlay(alignment: .trailing) {
							// - an overlay is used because the size of the
							//   group above is computed based on the _original
							//   size_ of the progress view before scaling,
							//   which introduces an unwanted padding at the
							//   top that is obvious when transitioning between
							//   status with the spinner or the bar.
							ProgressView()
								.scaleEffect(0.4, anchor: .center)
								.offset(.init(width: 30, height: 0))
						}
					
					
					Spacer()
				}.padding(.zero)
			}
		}
		.frame(width: (Self.ButtonWidth * 1.35).rounded(), alignment: .topLeading)
		.padding(.init(top: 5, leading: 0, bottom: 0, trailing: 0))
		.opacity(isImporting ? 1.0 : 0.0)
	}
		
	// - custom status text.
	private var statusText: String {
		guard isImporting else { return "" }
		let ret: String
		if !isStarted {
			ret = String(localized: "Calculating...", comment: "Status text displayed when the index file is being procssed to determine file size.")
		}
		else if isOptimizing {
			ret = String(localized: "Optimizing...", comment: "Status text displayed when the index file is being optimized after processing.")
		}
		else {
			ret = String(localized: "Importing...", comment: "Status text displayed when the index file is being parsed and imported.")
		}
		return ret
	}
}

// - display a preview of the view
#Preview("Not Started") {
    IndexImportView(isImporting: true, isStarted: false, isOptimizing: false, lineCount: 0, totalCount: 0)
		.frame(width: 700, height: 700)
		.environmentObject(MetDesignerDocument())
}

#Preview("Started") {
	IndexImportView(isImporting: true, isStarted: true, isOptimizing: false, lineCount: 3, totalCount: 15)
		.frame(width: 700, height: 700)
		.environmentObject(MetDesignerDocument())
}

#Preview("Optimizing") {
	IndexImportView(isImporting: true, isStarted: true, isOptimizing: true, lineCount: 15, totalCount: 15)
		.frame(width: 700, height: 700)
		.environmentObject(MetDesignerDocument())
}
