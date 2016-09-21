-- Copyright 2016 Nils Nordman <nino@nordman.org>
-- License: MIT (see LICENSE.md at the top-level directory of the distribution)

append = table.insert

builtin_whitelist_unused = {
  '_G',
  '...',
  '_',
  'tostring' -- due to string interpolations
}

builtin_whitelist_globals = {
  '_G'
  '_VERSION'
  'assert'
  'collectgarbage'
  'dofile'
  'error'
  'getfenv'
  'getmetatable'
  'ipairs'
  'load'
  'loadfile'
  'loadstring'
  'module'
  'next'
  'pairs'
  'pcall'
  'print'
  'rawequal'
  'rawget'
  'rawset'
  'require'
  'select'
  'setfenv'
  'setmetatable'
  'tonumber'
  'tostring'
  'type'
  'unpack'
  'xpcall'
  'coroutine'
  'debug'
  'io'
  'math'
  'os'
  'package'
  'string'
  'table'

  'true',
  'false',
  'nil'
}

config_for = (path) ->
  has_moonscript = pcall require, 'moonscript'
  look_for = { 'lint_config.lua' }
  if has_moonscript
    look_for[#look_for + 1] = 'lint_config.moon'

  exists = (f) ->
    fh = io.open f, 'r'
    if fh
      fh\close!
      return true

    false

  path = path\match('(.+)[/\\].+$') or path
  while path
    for name in *look_for
      config = "#{path}/#{name}"
      return config if exists(config)

    path = path\match('(.+)[/\\].+$')

  nil

load_config = (config_file, file) ->
  loader = loadfile
  if config_file\match('.moon$')
    loader = require("moonscript.base").loadfile

  chunk = assert loader(config_file)
  config = chunk! or {}
  opts = { }
  for list in *{'whitelist_globals', 'whitelist_unused'}
    if config[list]
      wl = {}
      for k, v in pairs config[list]
        if file\find(k)
          for token in *v
            append wl, token

      opts[list] = wl

  opts

instantiate = (opts) ->
  whitelist_unused = builtin_whitelist_unused
  if opts.whitelist_unused
    whitelist_unused = [t for t in *whitelist_unused]
    append(whitelist_unused, t) for t in *opts.whitelist_unused

  whitelist_unused = {k, true for k in *whitelist_unused}

  whitelist_globals = builtin_whitelist_globals
  if opts.whitelist_globals
    whitelist_globals = [t for t in *whitelist_globals]
    append(whitelist_globals, t) for t in *opts.whitelist_globals

  whitelist_globals = {k, true for k in *whitelist_globals}
  report_params = opts.report_params
  report_params = false if report_params == nil

  {
    :whitelist_globals,
    :whitelist_unused
    :report_params
  }

:config_for, :load_config, :instantiate
