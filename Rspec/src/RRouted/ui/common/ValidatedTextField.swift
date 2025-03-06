//
//  ValidatedTextField.swift
//  RRouted
// 
//  Created on 11/26/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  A custom text field that supports inline validation of content.
 *  DESIGN: The reference for this is the Proto4CustomTextFieldC
 * 		    prototype text field which favors validation only during
 * 			submission and focus changes and lacking validation
 * 			error indicators.
 *  DESIGN: The idea here is to perform custom formatting and validation
 * 			to overcome what appear to be some intrinsic limitations to
 * 			using a Formatter or FormatStyle w/o View.onChange support.
 * 	DESIGN: BIG: When onChange() is available, I think this should be
 * 			refactored probably to detect per-key modifications instead of
 *			just focus/submit updates.  I'm accepting some lesser behavior
 * 			in the mean time, with the assumption that certain UI efficiencies
 * 			aren't yet possible with this version of SwiftUI.
 *
 */
struct ValidatedTextField<T: Any, V: RRTextFieldValidator>: View where V.FieldType == T {
	private let titleKey: LocalizedStringKey
	private let validator: V.Type
	private let tfId: String
	@Binding private var value: T
	@State private var text: String = ""
	
	/*
	 *  Initialize the field.
	 */
	init(_ titleKey: LocalizedStringKey, validatedBy validator: V.Type, value: Binding<T>) {
		self.titleKey  = titleKey
		self.validator = validator
		self._value    = value
		
		// - assign an id to this view which dictates when it should be rebuilt,
		//   which must happen if the parent modifies the value.  It must not be empty
		//   for this to work though.
		self.tfId 	  = validator.formatDisplay(value.wrappedValue) + "-id"
	}

    var body: some View {
		TextField(titleKey, text: $text) { didBeginEditing in
			guard !didBeginEditing else { return }
			// ...detect focus changes to apply the mods.
			applySubmit()
		}
		.autocorrectionDisabled()
		.textFieldStyle(.squareBorder)			// ...seems to be the style for most property sheets.
		.background(.white)
		.shadow(radius: 0.25, y: 0.25)
		.onSubmit {
			// ...detec changes when hitting return
			applySubmit()
		}
		.onAppear(perform: {
			// - ensure the field is initialized from the data when
			//   updating the view.
			self.text = validator.formatDisplay(value)
		})
		.id(tfId)
    }
	
	private func applySubmit() {
		let conv = validator.toValue(text)
		guard case .success(let newVal) = conv else {
			// ...if invalid, reset the item to its former value
			Task { text = validator.formatDisplay(value) }
			return
		}
		value = newVal
	}
}

protocol ValidatableView : View {
	associatedtype T: Any
	var value: T { get set }
	associatedtype V: RRTextFieldValidator where V.FieldType == T
	var validator: V.Type { get }
}

/*
 *  Any use of the validated field assumes that formatting and
 *  validation are managed by a type that will convert to/from
 *  its fundamental type to both validate it and ensure a consistent
 *  output format.
 *  DESIGN: This handles nils better than classic Formatters and
 *  		doesn't crash like new FormatStyle modifiers in
 * 			out-of-range scenarios.
 */
protocol RRTextFieldValidator {
	associatedtype FieldType = Any
	
	static func toValue(_ text: String) -> Result<FieldType, Error>
	static func formatDisplay(_ value: FieldType) -> String
}
 
