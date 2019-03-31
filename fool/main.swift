//
//  main.swift
//  fool
//
//  Created by Uli Kusterer on 31.03.19.
//  Copyright © 2019 Uli Kusterer. All rights reserved.
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
		database = url.appendingPathComponent(".fool", isDirectory: true)
		objectsDir = database.appendingPathComponent("objects", isDirectory: true)
		commitsDir = database.appendingPathComponent("commits", isDirectory: true)
		
		if FileManager.default.fileExists(atPath: commitsDir.path) {
			revision = try FileManager.default.contentsOfDirectory(at: commitsDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]).count
		}
	}
	
	func commit() throws {
		var commit = ""
		
		try FileManager.default.createDirectory(at: objectsDir, withIntermediateDirectories: true, attributes: nil)
		try FileManager.default.createDirectory(at: commitsDir, withIntermediateDirectories: true, attributes: nil)
		
		try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]).forEach { currFile in
			var isDirectory: ObjCBool = false
			guard FileManager.default.fileExists(atPath: currFile.path, isDirectory: &isDirectory) && !isDirectory.boolValue else { return } // Skip directories.
			
			let contents = try String(contentsOf: currFile, encoding: .utf8)
			let currHash = contents.hash
			
			let objectPath = objectsDir.appendingPathComponent("\(currHash).txt").path;
			let relativePath = currFile.path.dropFirst(url.path.count + 1);
			if !FileManager.default.fileExists(atPath: objectPath) {
				try contents.write(toFile: objectPath, atomically: true, encoding: .utf8)
				print("Wrote \(relativePath) [\(currHash)]")
			} else {
				print("Unchanged \(relativePath)")
			}
			commit.append("\(currHash) \(relativePath)\n")
		}
		
		revision += 1
		try commit.write(to: commitsDir.appendingPathComponent("\(revision).txt"), atomically: true, encoding: .utf8)
	}
	
	func checkout(revision inputRevision: Int) throws {
		var actualRevision = inputRevision
		if actualRevision == 0 {
			actualRevision = revision
		}

		print("Revision \(actualRevision):");

		var existingFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles])

		let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(actualRevision).txt"), encoding: .utf8)
		
		var hasChanges = false

		try commitList.components(separatedBy: CharacterSet.newlines).forEach { currLine in
			let parts = currLine.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
			guard parts.count == 2 else { return }
			let currDestURL = url.appendingPathComponent("\(parts.last!)")
			let currHash = Int(parts.first!) ?? 0
			existingFiles.removeAll(where: { $0 == currDestURL })
			let objectFile = objectsDir.appendingPathComponent("\(currHash).txt");
			let existingContents = try? String(contentsOf: currDestURL, encoding: .utf8)
			let existingHash = (existingContents?.hash ?? 0)
			if existingHash != currHash {
				hasChanges = true
				let fileContents = try String(contentsOf: objectFile, encoding: .utf8)
				try FileManager.default.createDirectory(at: currDestURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
				try fileContents.write(to: currDestURL, atomically: true, encoding: .utf8)
				print("\t[\((existingHash == 0) ? "A" : "M")] \(parts.last!)")
			}
		}
		
		try existingFiles.forEach { currFile in
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
		var existingFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles])
		let commitList = try String(contentsOf: commitsDir.appendingPathComponent("\(revision).txt"), encoding: .utf8)
		
		var hasChanges = false
		
		try commitList.components(separatedBy: CharacterSet.newlines).forEach { currLine in
			let parts = currLine.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: { $0 == " " })
			guard parts.count == 2 else { return }
			let currDestPath = url.appendingPathComponent("\(parts.last!)").path
			if let foundIdx = existingFiles.firstIndex(where: { $0 == URL(fileURLWithPath: currDestPath) }) {
				existingFiles.remove(at: foundIdx)
				let originalHash = Int(parts.first!) ?? 0
				let fileContents = try String(contentsOfFile: currDestPath, encoding: .utf8)
				let currHash = fileContents.hash
				if currHash != originalHash {
					hasChanges = true
					print("\t[M] \(parts.last!)")
				}
			} else {
				hasChanges = true
				print("\t[D] \(parts.last!)")
			}
		}
		
		existingFiles.forEach { currFile in
			hasChanges = true
			let relativePath = currFile.path.dropFirst(url.path.count + 1);
			print("\t[A] \(relativePath)")
		}
		
		if !hasChanges {
			print("\tNo changes.")
		}
	}

}

let repo = try Repository(url: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

if CommandLine.arguments[1] == "commit" {
	try repo.commit()
} else if CommandLine.arguments[1] == "status" {
	try repo.status()
} else if CommandLine.arguments[1] == "checkout" {
	try repo.checkout(revision: Int(CommandLine.argc > 2 ? CommandLine.arguments[2] : "0") ?? 0)
}
