//
//  FirewallPopover+TextField.swift
//  RRouted
// 
//  Created on 11/19/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI
import RREngine

/*
 *  A custom text field that supports inline validation of network ports.
 */
struct NetworkPortNumberTextField: View {
	@Binding private var value: NetworkPortValue?
	
	/*
	 *  Initialize the field.
	 */
	init(value: Binding<Optional<NetworkPortValue>>) {
		self._value = value
	}

    var body: some View {
		ValidatedTextField("\(RRouted.limits.MinMaxNetworkPortValues.lowerBound, format: .number.grouping(.never))-\(RRouted.limits.MinMaxNetworkPortValues.upperBound, format: .number.grouping(.never))", validatedBy: FirewallPortValueValidator.self, value: $value)
    }
	
	// - validation for the port
	private struct FirewallPortValueValidator : RRTextFieldValidator {
		static func toValue(_ text: String) -> Result<NetworkPortValue?, Error> {
			let vText = text.trimmingCharacters(in: .whitespacesAndNewlines)
			
			// ...special case to correctly handle nil
			guard !vText.isEmpty else { return .success(nil)}
			
			guard let value = NetworkPortValue(vText),
				  RRouted.limits.MinMaxNetworkPortValues.contains(value) else {
				return .failure(RRoutedError.invalidFormat(reason: "The text '\(text)' cannot be converted into a valid port value."))
			}
			
			return .success(value)
		}
		
		static func formatDisplay(_ value: NetworkPortValue?) -> String {
			switch value {
			case .none:
				return ""
				
			case .some(let value):
				return "\(value)"
			}
		}
	}
}

/*
 *  A custom text field that supports inline validation of the connection backlog.
 */
struct NetworkClientBacklogTextField: View {
	@Binding private var value: UInt16
	
	/*
	 *  Initialize the field.
	 */
	init(value: Binding<UInt16>) {
		self._value = value
	}

	var body: some View {
		ValidatedTextField("0-\(RRouted.limits.MaxNetworkPortBacklog, format: .number.grouping(.never))", validatedBy: PortBacklogValueValidator.self, value: $value)
	}
	
	// - validation for the port
	private struct PortBacklogValueValidator : RRTextFieldValidator {
		static func toValue(_ text: String) -> Result<UInt16, Error> {
			let vText = text.trimmingCharacters(in: .whitespacesAndNewlines)
			
			guard !vText.isEmpty, let num = UInt16(vText), num <= RRouted.limits.MaxNetworkPortBacklog else {
				return .failure(RRoutedError.invalidFormat(reason: "The text '\(text)' cannot be converted into a valid backlog value."))
			}

			return .success(num)
		}
		
		static func formatDisplay(_ value: UInt16) -> String { "\(value)" }
	}
}

#Preview {
	VStack {
		NetworkPortNumberTextField(value: .constant(8080))
		NetworkClientBacklogTextField(value: .constant(16))
	}
}
