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


func printSyntax() {
	print("Syntax:")
	print("\tfool commit - Commit changes to the repository.")
	print("\tfool checkout [revision|branch] - Check out the given revision or the latest revision, or a particular branch from the repository.")
	print("\tfool log - Display the commit hashes for the current branch, in order from newest to oldest.")
	print("\tfool status - Display the status of the working copy, which files have changed, been added, deleted.")
	print("\tfool branch <branch name> - Create a new branch at the current commit.")
	print("\tfool branches - List all the branches in this repository.")
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
	try repo.checkout(revision: (CommandLine.arguments.count > 2) ? CommandLine.arguments[2] : "")
} else if CommandLine.arguments[1] == "branch" {
	try repo.branch(name: (CommandLine.arguments.count > 2) ? CommandLine.arguments[2] : "")
} else if CommandLine.arguments[1] == "log" {
	try repo.log()
} else if CommandLine.arguments[1] == "branches" {
	try repo.branches()
} else {
	printSyntax()
}
