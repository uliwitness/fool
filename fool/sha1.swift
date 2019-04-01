//
//  main.swift
//  fool
//
//  Created by Uli Kusterer on 31.03.19.
//	Copyright 2019 by Uli Kusterer.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	1. The origin of this software must not be misrepresented; you must not
//	claim that you wrote the original software. If you use this software
//	in a product, an acknowledgment in the product documentation would be
//	appreciated but is not required.
//
//	2. Altered source versions must be plainly marked as such, and must not be
//	misrepresented as being the original software.
//
//	3. This notice may not be removed or altered from any source
//	distribution.
//

import Foundation
import CommonCrypto

extension String {
	func sha1() -> String {
		let data = Data(self.utf8)
		var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
		data.withUnsafeBytes {
			_ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
		}
		let hexBytes = digest.map { String(format: "%02hhx", $0) }
		return hexBytes.joined()
	}
}
