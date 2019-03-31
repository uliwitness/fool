#  Fool

A tiny study on how Git works (how to keep multiple revisions of files in some kind of "repository").

Implements a simple command line tool.

## Syntax

All commands operate on the current directory

* **fool commit** - Commit changes to the repository.
* **fool checkout [revision]** - Check out the given revision (or the latest revision) from the repository.
* **fool status** - Display the status of the working copy, which files have changed, been added, deleted.


## Design

As a study, Fool only works with text files right now. That was easiest to code and is easiest to play with. In fact, even the database is in easily-readable text files. It also ignores hidden files (again, because that was easier than adding ignore file support).

Like Git, fool creates a hidden folder at the root of the current directory (though Fool doesn't require an `init` command, it just implicitly creates it when you commit). The hidden folder contains two sub-folders:

* **objects** This folder contains the files' contents, with their name the hash of the file
* **commits** this folder contains the directory structure for each commit, with one file per line. The line starts with the hash of the contents for this file, followed by a space, followed by the relative path where the file will be written (including its name).

## License

	Copyright 2019 by Uli Kusterer.

	This software is provided 'as-is', without any express or implied
	warranty. In no event will the authors be held liable for any damages
	arising from the use of this software.

	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented; you must not
	claim that you wrote the original software. If you use this software
	in a product, an acknowledgment in the product documentation would be
	appreciated but is not required.

	2. Altered source versions must be plainly marked as such, and must not be
	misrepresented as being the original software.

	3. This notice may not be removed or altered from any source
	distribution.
