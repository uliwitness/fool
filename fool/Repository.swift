//
//  Repository.swift
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

class Repository {
	let url: URL
	let database: URL
	let objectsDir: URL
	let commitsDir: URL
	let branchesDir: URL
	var head: String = ""
	var branch: String = "master"

	init(url: URL) throws {
		self.url = url
		
		// Build the URLs for all the subfolders for our repository metadata folder:
		database = url.appendingPathComponent(".fool", isDirectory: true)
		objectsDir = database.appendingPathComponent("objects", isDirectory: true)
		commitsDir = database.appendingPathComponent("commits", isDirectory: true)
		branchesDir = database.appendingPathComponent("branches", isDirectory: true)

		if FileManager.default.fileExists(atPath: branchesDir.path) {
			head = (try? String(contentsOf: branchesDir.appendingPathComponent("head.txt"), encoding: .utf8)) ?? ""
		}
	}
	
	func commit() throws {
		var commit = "\(head)\n"
		
		// Ensure our metadata folder and the subfolders we need to store commits exist:
		try FileManager.default.createDirectory(at: objectsDir, withIntermediateDirectories: true, attributes: nil)
		try FileManager.default.createDirectory(at: commitsDir, withIntermediateDirectories: true, attributes: nil)
		try FileManager.default.createDirectory(at: branchesDir, withIntermediateDirectories: true, attributes: nil)

		// Loop over all files, and add the contents for all new ones to the objects folder:
		try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]).forEach { currFile in
			var isDirectory: ObjCBool = false
			guard FileManager.default.fileExists(atPath: currFile.path, isDirectory: &isDirectory) && !isDirectory.boolValue else { return } // Skip directories.
			
			// Read & hash the file:
			let contents = try String(contentsOf: currFile, encoding: .utf8)
			let currHash = contents.sha1()
			
			let objectPath = objectsDir.appendingPathComponent("\(currHash).txt").path;
			let relativePath = currFile.path.dropFirst(url.path.count + 1);
			
			// If we have a file with identical contents already, skip it, otherwise write the contents to objects DB:
			if !FileManager.default.fileExists(atPath: objectPath) {
				try contents.write(toFile: objectPath, atomically: true, encoding: .utf8)
				print("Wrote \(relativePath) [\(currHash)]")
			} else {
				print("Unchanged \(relativePath)")
			}
			
			// Append an entry with the content -> path association for this file into the commit:
			commit.append("\(currHash) \(relativePath)\n")
		}
		
		// Actually create a new commit file with the data we just collected:
		head = commit.sha1()
		try commit.write(to: commitsDir.appendingPathComponent("\(head).txt"), atomically: true, encoding: .utf8)
		try head.write(to: branchesDir.appendingPathComponent("\(branch).txt"), atomically: true, encoding: .utf8)
		try head.write(to: branchesDir.appendingPathComponent("head.txt"), atomically: true, encoding: .utf8)
	}
	
	func checkout(revision inputRevision: String) throws {
		var actualRevision = inputRevision
		if actualRevision == "" {
			actualRevision = head
		}
		if actualRevision == "" {
			print("Repository is empty.");
			return
		}
		
		print("Revision \(actualRevision):");
		
		// Put the URLs of all files in the working copy into filesToRemove, so we can later delete files not part of this commit:
		var filesToRemove = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles])
		
		let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(actualRevision).txt"), encoding: .utf8)
		
		var hasChanges = false
		var parentCommit: String?
		
		try commitList.components(separatedBy: CharacterSet.newlines).forEach { currLine in
			if parentCommit == nil {
				parentCommit = currLine
				return
			}
			let parts = currLine.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
			guard parts.count == 2 else { return } // Ignore the trailing empty line in the commits file.
			
			// Extract the info about the current file in the commit:
			let currDestURL = url.appendingPathComponent("\(parts.last!)")
			let currHash = parts.first ?? ""
			
			// Remove this file from filesToRemove, it should stay in the commit:
			filesToRemove.removeAll(where: { $0 == currDestURL })
			
			let objectFile = objectsDir.appendingPathComponent("\(currHash).txt");
			
			// Read any existing file and determine its hash:
			let existingContents = try? String(contentsOf: currDestURL, encoding: .utf8)
			let existingHash = (existingContents?.sha1() ?? "")
			if existingHash != currHash { // Hashes differ (either new file, or modified)?
				hasChanges = true
				try FileManager.default.createDirectory(at: currDestURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil) // Create any enclosing folders that might not exist yet.
				// Copy the contents from the objects folder to the actual path in the commit:
				let fileContents = try String(contentsOf: objectFile, encoding: .utf8)
				try fileContents.write(to: currDestURL, atomically: true, encoding: .utf8)
				print("\t[\((existingHash == "") ? "A" : "M")] \(parts.last!)")
			}
		}
		
		// Now any leftover files are not part of the commit and should be deleted:
		try filesToRemove.forEach { currFile in
			try FileManager.default.removeItem(at: currFile)
			let relativePath = currFile.path.dropFirst(url.path.count + 1);
			print("\t[D] \(relativePath)")
			hasChanges = true
		}
		
		if !hasChanges {
			print("\tNo changes.")
		}
	}
	
	func status() throws {
		print("Revision \(head):");
		
		// List all files in the folder, so we can later detect added files:
		var addedFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles])
		
		let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(head).txt"), encoding: .utf8)
		
		var hasChanges = false
		
		try commitList.components(separatedBy: CharacterSet.newlines).forEach { currLine in
			let parts = currLine.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
			guard parts.count == 2 else { return } // Skip empty line at end of commit file.
			
			// Check if the file in the commit exists:
			let currDestPath = url.appendingPathComponent("\(parts.last!)").path
			if let foundIdx = addedFiles.firstIndex(where: { $0 == URL(fileURLWithPath: currDestPath) }) { // Exists!
				addedFiles.remove(at: foundIdx) // Remove from list of added files, it was in the commit already.
				
				// Determine the hash of the file in the working copy to determine whether it changed:
				let originalHash = parts.first ?? ""
				let fileContents = try String(contentsOfFile: currDestPath, encoding: .utf8)
				let currHash = fileContents.sha1()
				if currHash != originalHash {
					hasChanges = true
					print("\t[M] \(parts.last!)")
				}
			} else { // Doesn't exist. Deleted!
				hasChanges = true
				print("\t[D] \(parts.last!)")
			}
		}
		
		// Now list all files left in the addedFiles array, must have been added by user:
		addedFiles.forEach { currFile in
			hasChanges = true
			let relativePath = currFile.path.dropFirst(url.path.count + 1);
			print("\t[A] \(relativePath)")
		}
		
		if !hasChanges {
			print("\tNo changes.")
		}
	}

	func log() throws {
		guard branch != "", let revision = try? String(contentsOf: branchesDir.appendingPathComponent("\(branch).txt"), encoding: .utf8) else {
			print("Empty repository.")
			return
		}
		
		var currRevision = revision

		while true {
			print("\(currRevision)")
			
			let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(currRevision).txt"), encoding: .utf8)
			currRevision = commitList.components(separatedBy: CharacterSet.newlines).first ?? ""
			
			if currRevision == "" {
				break
			}
		}
	}
}
