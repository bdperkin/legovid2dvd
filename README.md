---
generator: 'DocBook XSL Stylesheets V1.78.1'
title: legovid2dvd
...

Name
----

legovid2dvd — LEGO® video downloader and DVD authoring tool

Synopsis
--------

*legovid2dvd* [ *-q* | *--quiet* ] [ *-v* | *--verbose* ]
[ *-d* | *--debug* ] [ *-C* | *--curlvrbs* ] [ *-l* | *--list* ] [ *-g*
*gallery* | *--gallery* = *gallery* ] [ *-t*
*gallery* | *--theme* = *gallery* ]

*legovid2dvd* { *--version* | *-V* }

*legovid2dvd* { *--help* | *-h* }

*legovid2dvd* { *--man* | *-m* }

DESCRIPTION
-----------

The legovid2dvd(1) command is a Perl script to download LEGO® videos,
convert them, and author a DVD.

OPTIONS
-------

Command line options are used to specify various startup options for
legovid2dvd:


 *-a* *attempts*, *--attempts* = *attempts* 
:   Count of latency tests to perform against selected server.

 *-C*, *--curlvrbs* 
:   Set CURLOPT\_VERBOSE option to make the fetching more
    verbose/talkative.

 *-d*, *--debug* 
:   Debug output.

 *-D* *directory*, *--download* = *directory* 
:   Specify a specific download directory.

 *-g* *gallery*, *--gallery* = *gallery* 
:   Specify a specific gallery by name. (see list option)

 *-h*, *--help* 
:   Print or show help information and exit.

 *-l*, *--list* 
:   Print a list of gallery names.

 *-m*, *--man* 
:   Print the entire manual page and exit.

 *-q*, *--quiet* 
:   Quiet output.

 *-t* *gallery*, *--theme* = *gallery* 
:   Specify a specific theme (gallery) by name. (see list option)

 *-v*, *--verbose* 
:   Verbose output.

 *-V*, *--version* 
:   Print or show the program version and release number and exit.

EXIT STATUS
-----------

The legovid2dvd return code to the parent process (or caller) when it
has finished executing may be one of:


 *0* 
:   Success.

 *1* 
:   Failure (syntax or usage error; configuration error; unexpected
    error).

BUGS
----

Report any issues at:
[https://github.com/bdperkin/legovid2dvd/issues](https://github.com/bdperkin/legovid2dvd/issues)

AUTHORS
-------

Brandon Perkins \<[bperkins@redhat.com](mailto:bperkins@redhat.com)\>

RESOURCES
---------

GitHub:
[https://github.com/bdperkin/legovid2dvd](https://github.com/bdperkin/legovid2dvd)

COPYING
-------

Copyright (C) 2014-2014 Brandon Perkins
\<[bperkins@redhat.com](mailto:bperkins@redhat.com)\>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
