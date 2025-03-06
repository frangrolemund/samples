//
//  OperatingIndicatorView.swift
//  RRouted
// 
//  Created on 11/7/23
//  Copyright © 2023 RealProven, LLC.  All rights reserved. 
//

import SwiftUI

/*
 *  Displays a visual indication of operating status.
 */
struct OperatingIndicatorView: View {
	private var indicatorStatus: IndicatorStatus
	
	// - initialize the indicator
	init(indicatorStatus: IndicatorStatus = .disabled) {
		self.indicatorStatus = indicatorStatus
	}
	
	enum IndicatorStatus {
		case disabled
		case error
		case warning
		case ok
	}
	
    var body: some View {
		ZStack {
			Circle()
				.foregroundStyle(indicatorStatus.color)
			Circle()
				.stroke(.secondary, lineWidth: 0.25)
		}
		.frame(width: 8, height: 8)
    }
}

/*
 *  Internal
 */
fileprivate extension OperatingIndicatorView.IndicatorStatus {
	var color: Color {
		switch self {
		case .disabled:
			return RRouted.brand.disabledColor
			
		case .error:
			return RRouted.brand.errorColor
			
		case .warning:
			return RRouted.brand.warningColor
			
		case .ok:
			return RRouted.brand.okColor
		}
	}
}

#Preview {
	HStack {
		OperatingIndicatorView(indicatorStatus: .disabled)
		OperatingIndicatorView(indicatorStatus: .error)
		OperatingIndicatorView(indicatorStatus: .warning)
		OperatingIndicatorView(indicatorStatus: .ok)
	}
}
