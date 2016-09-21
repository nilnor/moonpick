local append = table.insert
local builtin_whitelist_unused = {
  '_G',
  '...',
  '_',
  'tostring'
}
local builtin_whitelist_globals = {
  '_G',
  '_VERSION',
  'assert',
  'collectgarbage',
  'dofile',
  'error',
  'getfenv',
  'getmetatable',
  'ipairs',
  'load',
  'loadfile',
  'loadstring',
  'module',
  'next',
  'pairs',
  'pcall',
  'print',
  'rawequal',
  'rawget',
  'rawset',
  'require',
  'select',
  'setfenv',
  'setmetatable',
  'tonumber',
  'tostring',
  'type',
  'unpack',
  'xpcall',
  'coroutine',
  'debug',
  'io',
  'math',
  'os',
  'package',
  'string',
  'table',
  'true',
  'false',
  'nil'
}
local config_for
config_for = function(path)
  local has_moonscript = pcall(require, 'moonscript')
  local look_for = {
    'lint_config.lua'
  }
  if has_moonscript then
    table.insert(look_for, 1, 'lint_config.moon')
  end
  local exists
  exists = function(f)
    local fh = io.open(f, 'r')
    if fh then
      fh:close()
      return true
    end
    return false
  end
  path = path:match('(.+)[/\\].+$') or path
  while path do
    for _index_0 = 1, #look_for do
      local name = look_for[_index_0]
      local config = tostring(path) .. "/" .. tostring(name)
      if exists(config) then
        return config
      end
    end
    path = path:match('(.+)[/\\].+$')
  end
  return nil
end
local load_config_from
load_config_from = function(config, file)
  if type(config) == 'string' then
    local loader = loadfile
    if config:match('.moon$') then
      loader = require("moonscript.base").loadfile
    end
    local chunk = assert(loader(config))
    config = chunk() or { }
  end
  local opts = { }
  local _list_0 = {
    'whitelist_globals',
    'whitelist_unused'
  }
  for _index_0 = 1, #_list_0 do
    local list = _list_0[_index_0]
    if config[list] then
      local wl = { }
      for k, v in pairs(config[list]) do
        if file:find(k) then
          for _index_1 = 1, #v do
            local token = v[_index_1]
            append(wl, token)
          end
        end
      end
      opts[list] = wl
    end
  end
  return opts
end
local instantiate
instantiate = function(opts)
  local whitelist_unused = builtin_whitelist_unused
  if opts.whitelist_unused then
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #whitelist_unused do
        local t = whitelist_unused[_index_0]
        _accum_0[_len_0] = t
        _len_0 = _len_0 + 1
      end
      whitelist_unused = _accum_0
    end
    local _list_0 = opts.whitelist_unused
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      append(whitelist_unused, t)
    end
  end
  do
    local _tbl_0 = { }
    for _index_0 = 1, #whitelist_unused do
      local k = whitelist_unused[_index_0]
      _tbl_0[k] = true
    end
    whitelist_unused = _tbl_0
  end
  local whitelist_globals = builtin_whitelist_globals
  if opts.whitelist_globals then
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #whitelist_globals do
        local t = whitelist_globals[_index_0]
        _accum_0[_len_0] = t
        _len_0 = _len_0 + 1
      end
      whitelist_globals = _accum_0
    end
    local _list_0 = opts.whitelist_globals
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      append(whitelist_globals, t)
    end
  end
  do
    local _tbl_0 = { }
    for _index_0 = 1, #whitelist_globals do
      local k = whitelist_globals[_index_0]
      _tbl_0[k] = true
    end
    whitelist_globals = _tbl_0
  end
  local report_params = opts.report_params
  if report_params == nil then
    report_params = false
  end
  return {
    whitelist_globals = whitelist_globals,
    whitelist_unused = whitelist_unused,
    report_params = report_params,
    allow_unused_param = function(p)
      return not report_params or whitelist_unused[p]
    end
  }
end
return {
  config_for = config_for,
  load_config_from = load_config_from,
  instantiate = instantiate
}
