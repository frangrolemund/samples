//
//  MDSelectionState.swift
//  MetDesigner
// 
//  Created on 2/8/24
//  Copyright © 2024 Francis Grolemund.  All rights reserved. 
//

import Foundation
import MetModel

// - records active selection in the document.
enum MDSelectionState : Codable, Equatable {
	case exhibitReference(_ eRefId: MMObjectIdentifier)
	
	var asExhibitRefID: MMObjectIdentifier? {
		guard case .exhibitReference(let eRefId) = self else {
			return nil
		}
		return eRefId
	}
}
