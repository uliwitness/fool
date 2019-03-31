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

class Repository {
	let url: URL
	let database: URL
	let objectsDir: URL
	let commitsDir: URL
	var revision: Int = 0
	
	init(url: URL) throws {
		self.url = url

		// Build the URLs for all the subfolders for our repository metadata folder:
		database = url.appendingPathComponent(".fool", isDirectory: true)
		objectsDir = database.appendingPathComponent("objects", isDirectory: true)
		commitsDir = database.appendingPathComponent("commits", isDirectory: true)
		
		// Count the number of files in "commits" directory to initialize our highest commit ID:
		if FileManager.default.fileExists(atPath: commitsDir.path) {
			revision = try FileManager.default.contentsOfDirectory(at: commitsDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]).count
		}
	}
	
	func commit() throws {
		var commit = ""
		
		// Ensure our metadata folder and the subfolders we need to store commits exist:
		try FileManager.default.createDirectory(at: objectsDir, withIntermediateDirectories: true, attributes: nil)
		try FileManager.default.createDirectory(at: commitsDir, withIntermediateDirectories: true, attributes: nil)
		
		// Loop over all files, and add the contents for all new ones to the objects folder:
		try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]).forEach { currFile in
			var isDirectory: ObjCBool = false
			guard FileManager.default.fileExists(atPath: currFile.path, isDirectory: &isDirectory) && !isDirectory.boolValue else { return } // Skip directories.
			
			// Read & hash the file:
			let contents = try String(contentsOf: currFile, encoding: .utf8)
			let currHash = contents.hash
			
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
		revision += 1
		try commit.write(to: commitsDir.appendingPathComponent("\(revision).txt"), atomically: true, encoding: .utf8)
	}
	
	func checkout(revision inputRevision: Int) throws {
		var actualRevision = inputRevision
		if actualRevision == 0 {
			actualRevision = revision
		}

		print("Revision \(actualRevision):");

		// Put the URLs of all files in the working copy into filesToRemove, so we can later delete files not part of this commit:
		var filesToRemove = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles])

		let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(actualRevision).txt"), encoding: .utf8)
		
		var hasChanges = false

		try commitList.components(separatedBy: CharacterSet.newlines).forEach { currLine in
			let parts = currLine.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
			guard parts.count == 2 else { return } // Ignore the trailing empty line in the commits file.
			
			// Extract the info about the current file in the commit:
			let currDestURL = url.appendingPathComponent("\(parts.last!)")
			let currHash = Int(parts.first!) ?? 0
			
			// Remove this file from filesToRemove, it should stay in the commit:
			filesToRemove.removeAll(where: { $0 == currDestURL })
			
			let objectFile = objectsDir.appendingPathComponent("\(currHash).txt");
			
			// Read any existing file and determine its hash:
			let existingContents = try? String(contentsOf: currDestURL, encoding: .utf8)
			let existingHash = (existingContents?.hash ?? 0)
			if existingHash != currHash { // Hashes differ (either new file, or modified)?
				hasChanges = true
				try FileManager.default.createDirectory(at: currDestURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil) // Create any enclosing folders that might not exist yet.
				// Copy the contents from the objects folder to the actual path in the commit:
				let fileContents = try String(contentsOf: objectFile, encoding: .utf8)
				try fileContents.write(to: currDestURL, atomically: true, encoding: .utf8)
				print("\t[\((existingHash == 0) ? "A" : "M")] \(parts.last!)")
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
		print("Revision \(revision):");
		
		// List all files in the folder, so we can later detect added files:
		var addedFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles])
		
		let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(revision).txt"), encoding: .utf8)
		
		var hasChanges = false
		
		try commitList.components(separatedBy: CharacterSet.newlines).forEach { currLine in
			let parts = currLine.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
			guard parts.count == 2 else { return } // Skip empty line at end of commit file.
			
			// Check if the file in the commit exists:
			let currDestPath = url.appendingPathComponent("\(parts.last!)").path
			if let foundIdx = addedFiles.firstIndex(where: { $0 == URL(fileURLWithPath: currDestPath) }) { // Exists!
				addedFiles.remove(at: foundIdx) // Remove from list of added files, it was in the commit already.
				
				// Determine the hash of the file in the working copy to determine whether it changed:
				let originalHash = Int(parts.first!) ?? 0
				let fileContents = try String(contentsOfFile: currDestPath, encoding: .utf8)
				let currHash = fileContents.hash
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

}

func printSyntax() {
	print("Syntax:")
	print("\tfool commit - Commit changes to the repository.")
	print("\tfool checkout [revision] - Check out the given revision (or the latest revision) from the repository.")
	print("\tfool status - Display the status of the working copy, which files have changed, been added, deleted.")
}

// MARK: entry point

let repo = try Repository(url: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

if CommandLine.arguments.count < 2 {
	printSyntax()
} else if CommandLine.arguments[1] == "commit" {
	try repo.commit()
} else if CommandLine.arguments[1] == "status" {
	try repo.status()
} else if CommandLine.arguments[1] == "checkout" {
	try repo.checkout(revision: Int(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "0") ?? 0)
} else {
	printSyntax()
}
