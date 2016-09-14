# Moonpick

## What is it?

Moonpick is an alternative linter for [Moonscript](http://moonscript.org/).
While moonscript ships with a [built-in
linter](http://moonscript.org/reference/command_line.html#command-line-tools/moonc/linter),
that one is currently limited in what it can detect. The built-in linter will
for instance detect unused variables, but only for a subset of all possible
unused declarations. It will not detect unused import variables, decomposition
variables or unused functions. Moonpick was born in an attempt to detect the
above and more.

## Current status

Note that Moonpick is very young at this stage, and while it has been run with
success on larger code bases it may very well produce false positives and
incorrect reports. Should you encounter this then please open an issue with a
code sample that illustrates the incorrect behaviour.

## License

Moonpick is released under the MIT license (see the LICENSE file for the full
details).
