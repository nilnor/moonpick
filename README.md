# Moonpick

[![Build Status](https://travis-ci.org/nilnor/moonpick.svg?branch=master)](https://travis-ci.org/nilnor/moonpick)

## What is it?

Moonpick is an alternative linter for [Moonscript](http://moonscript.org/).
While moonscript ships with a [built-in
linter](http://moonscript.org/reference/command_line.html#command-line-tools/moonc/linter),
it is currently limited in what it can detect. The built-in linter will for
instance detect unused variables, but only for a subset of all possible unused
declarations. It will not detect unused import variables, decomposition
variables, unused functions, etc.. Moonpick was born in an attempt to detect the
above and more.

## Installation and usage

Moonpick can be installed via [Luarocks](https://luarocks.org/):

```
$ luarocks install moonpick
```

It can then be run from command line:

```shell
$ moonpick <path-to-file>
```

The output closely mimics the output of Moonscript's built-in linter.

It's also easily bundled into a standalone application as it's sole dependency
is moonscript. See the [API](#API) section for more information on how to run
it programmatically.

## What does it detect?

### Unused variables

Moonpick detects unused variables in all their forms, whether they're explicitly
used as variables via assigments or implicitly created as part of a `import`
statement, table decomposition statement, etc.

### Unused function parameters

Moonpick can also detect and complain about declared but unused function
parameters. This is not enabled by default, as it's very common to have unused
parameters. E.g. a function might follow an external API and still wants to
indicate the available parameters even though not all are used. To enable this,
set the `report_params` [configuration](#configuration) option to `true`.

Moonpick ships with a default configuration that whitelists any parameter
starting with a '_', providing a way of keeping the documentational aspects for
a function and still pleasing the linter.

### Unused loop variables

Unused loop variables are detected. It's possible to disable this completely in
the [configuration](#configuration), or to provide an explicit whitelist only
for loop variables. Moonpick ships with a default configuration that whitelists
the arguments 'i' and 'j', or any variable starting with a '_'.

### Undefined global accesses

Similar to the built-in linter Moonpick detects undefined references.

### Declaration shadowing

Declaration shadowing occurs whenever a declaration shadows an earlier
declaration with the same name. Consider the following code:

```moonscript
my_mod = require 'my_mod'

-- [.. more code in between.. ]

for my_mod in get_modules('foo')
  my_mod.bar!
```

While it in the example above is rather clear that the `my_mod` declared in the
loop is different from the top level `my_mod`, this can quickly become less
clear should more code be inserted between the for declaration and later usage.
At that point the code becomes ambiguous. Declaration shadowing helps with this
by ensuring that each variable is defined at most once, in an unambiguous
manner.

The detection can be turned off completely by setting the `report_shadowing`
configuration variable to false, and the whitelisting can be configured by
specifying a `whitelist_shadowing` configuration list.

_Note that for versions of Moonscript earlier than 0.5 these kind of shadowings
would actually just re-use the prior declaration, leading to easily overlooked
and confounding bugs._

## Configuration

Moonpick supports a super set of the same configuration file and format as the
[built-in linter](http://moonscript.org/reference/command_line.html#command-line-tools/moonc/linter).

It provides additional configuration options by adding support for configuring
linting of function parameters and loop variables, and also allows Lua patterns
in all whitelists. Linter configuration files can be written in either Lua or
Moonscript (`lint_config.lua` and `lint_config.moon` respectively).

See the below example (lint_config.moon, using Moonscript syntax):

```moonscript
{
  whitelist_globals: {
    -- whitelist for all files
    ["."]: { 'always_ignore' },

    -- whitelist for files matching 'spec'
    spec: { 'test_helper' },
  }

  whitelist_params: {
    -- whitelist params for all files
    ["."]: { 'my_param' },

    -- ignore unused param for files in api
    api: { 'extra_info' },
  }

  whitelist_loop_variables: {
    -- always allow loop variables 'i', 'j', 'k', as well as any
    -- variable starting with '_' (using a Lua pattern)
    ["."]: { 'i', 'j', 'k', '^_' },
  }

  -- general whitelist for unused variables if desired for
  -- some reason
  whitelist_unused: {
    ["."]: {},
  }
  -- loop variable and function parameter linting can be disabled
  -- completely by uncommenting the below

  -- report_loop_variables: false
  -- report_params: false
}
```

A whitelist item is treated as a pattern if it consist of anything other than
alphanumeric characters.

## API

### moonpick

```lua
local moonpick = require('moonpick')
```

#### lint(code, config = {})

Lints the given code in `code`, returning a table of linting inspections.
`config` is the linting configuration to use for the file, and can contain flat
versions of the elements typically found in a configuration file
(`whitelist_globals`, `whitelist_params`, `whitelist_loop_variables`,
`whitelist_unused`, `report_params`, `report_loop_variables`).

Example of a configuration table (Lua syntax):

```lua
local moonpick = require('moonpick')
local code = 'a = 2'
moonpick.lint(code, {
  whitelist_globals = { 'foo', 'bar', }
  whitelist_params = { '^_+', 'other_+'}
})
```

The returned inspections table would look like this for the above example:

```lua
{
  {
    line = 1,
    pos = 1,
    msg = 'declared but unused - `a`',
    code = 'a = 2'
  }
}

```

#### lint_file(file, opts = {})

Lints the given `file`, returning a table of linting inspections. `opts` can
currently contain one value, `lint_config`, which specifies the configuration
file to load configuration from.

### moonpick.config

```lua
local moonpick_config = require('moonpick.config')
```

#### config_for(path)

Returns the path of relevant configuration file for `path`, or `nil` if none was found.

#### load_config_from(config_path, file)

Loads linting configuration for the file `file` from the configuration file
given by `config_path`. The returned configuration will be a table flattened
configuration options for `file`.

#### evaluator(config)

Returns an evaluator instance for the given linting options (e.g. as returned by
`load_config_from`). The evaluator instance provides the following four
functions (note that these are functions, to be invoked using the ordinary dot
operator `.`):

`allow_global_access`, `allow_unused_param`, `allow_unused_loop_variable`,
`allow_unused`.

All of these take as their first argument a symbol (as string) and returns
`true` or `false` depending on whether the symbol passes linting or not.

## Current status

Note that Moonpick is rather young at this stage, and while it has been run with
success on larger code bases it may very well produce false positives and
incorrect reports. Should you encounter this then please open an issue with a
code sample that illustrates the incorrect behaviour.

## License

Moonpick is released under the MIT license (see the LICENSE file for the full
details).

## Running the specs

Tests require `busted` to run, as well as the `pl` module (Penlight - `luarock
install penlight`). Just run `busted` in the project's root directory.
