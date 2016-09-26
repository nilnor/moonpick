-- Copyright 2016 Nils Nordman <nino@nordman.org>
-- License: MIT (see LICENSE.md at the top-level directory of the distribution)

parse = require "moonscript.parse"
{:pos_to_line, :get_line} = require "moonscript.util"
config = require "moonpick.config"

append = table.insert

Scope = (node, parent) ->
  assert node, "Missing node"
  declared = {}
  used = {}
  scopes = {}
  pos = node[-1]
  if not pos and parent
    pos = parent.pos

  {
    :parent,
    :declared,
    :used,
    :scopes,
    :node,
    :pos,
    type: 'default'

    has_declared: (name) =>
      return true if declared[name]
      parent and parent\has_declared(name)

    has_parent: (type) =>
      return false unless parent
      return true if parent.type == type
      return parent\has_parent type

    add_declaration: (name, opts) =>
      declared[name] = opts

    add_assignment: (name, ass) =>
      return if @has_declared name
      if not parent or not parent\has_declared(name)
        declared[name] = ass

    add_ref: (name, ref) =>
      if declared[name]
        used[name] = ref
      else if parent and parent\has_declared(name)
        parent\add_ref name, ref
      else
        used[name] = ref

    open_scope: (node, type) =>
      scope = Scope node, @
      scope.type = type
      append scopes, scope
      scope
  }

has_subnode = (node, types) ->
  return false unless type(node) == 'table'
  for t in *types
    return true if node[1] == t

  for n in *node
    return true if has_subnode n, types

  false

is_loop_assignment = (list) ->
  node = list[1]
  return false unless type(node) == 'table'
  return false unless node[1] == 'chain'
  last = node[#node]
  return false unless last[1] == 'call'
  c_target = last[2]
  return false unless type(c_target) == 'table' and #c_target == 1
  op = c_target[1][1]
  op == 'for' or op == 'foreach'

handlers = {
  update: (node, scope, walk) ->
    target, val = node[2], node[4]

    unless scope.is_wrapper
      if is_loop_assignment({val})
        scope = scope\open_scope node, 'loop-update'
        scope.is_wrapper = true

    if target[1] == 'ref'
      scope\add_assignment target[2], { pos: target[-1] }
    else
      walk target, scope

    walk {val}, scope

  assign: (node, scope, walk) ->
    targets = node[2]
    values = node[3]
    pos = node[-1]

    unless scope.is_wrapper
      if is_loop_assignment(values)
        scope = scope\open_scope node, 'loop-assignment'
        scope.is_wrapper = true

    for t in *targets
      switch t[1] -- type of target
        when 'ref' -- plain assignment, e.g. 'x = 1'
          scope\add_assignment t[2], { pos: t[-1] or pos }
        when 'chain'
          -- chained assignment, e.g. 'x.foo = 1' - walk all references
          walk t, scope
        when 'table' -- handle decomposition syntax, e.g. '{:foo} = table'
          key_targets = t[2]
          for k_target in *key_targets
            for field in *k_target
              if type(field) == 'table' and field[1] == 'ref'
                scope\add_assignment field[2], { pos: field[-1] or pos }

    walk values, scope

  chain: (node, scope, walk) ->
    if not scope.is_wrapper and is_loop_assignment({node})
      scope = scope\open_scope node, 'chain'
      scope.is_wrapper = true

    walk node, scope

  ref: (node, scope) ->
    scope\add_ref node[2], pos: node[-1]

  fndef: (node, scope, walk) ->
    params, f_type, body = node[2], node[4], node[5]
    t = f_type == 'fat' and 'method' or 'function'
    scope = scope\open_scope node, t
    for p in *params
      def = p[1]
      if type(def) == 'string'
        scope\add_declaration def, pos: node[-1], type: 'param'
        if p[2] -- default parameter assignment
          walk {p[2]}, scope
      elseif type(def) == 'table' and def[1] == 'self'
        scope\add_declaration def[2], pos: node[-1], type: 'param'
        scope\add_ref def[2], pos: node[-1]
        if p[2] -- default parameter assignment
          walk {p[2]}, scope
      else
        walk {p}, scope

    walk body, scope

  for: (node, scope, walk) ->
    var, args, body = node[2], node[3], node[4]

    unless scope.is_wrapper
      scope = scope\open_scope node, 'for'

    scope\add_declaration var, pos: node[-1], type: 'loop-var'

    walk args, scope
    walk body, scope if body

  foreach: (node, scope, walk) ->
    vars, args, body = node[2], node[3], node[4]

    if not body
      body = args
      args = nil

    unless scope.is_wrapper
      scope = scope\open_scope node, 'for-each'

    for name in *vars
      if type(name) == 'string'
        scope\add_declaration name, pos: node[-1], type: 'loop-var'

    walk args, scope if args
    walk body, scope

  declare_with_shadows: (node, scope, walk) ->
    names = node[2]
    for name in *names
      scope\add_declaration name, pos: node[-1]

  export: (node, scope, walk) ->
    names, vals = node[2], node[3]
    if type(names) == 'string' -- `export *`
      scope.exported_from = node[-1]
    else
      for name in *names
        scope\add_declaration name, pos: node[-1], is_exported: true, type: 'export'

    if vals
      walk {vals}, scope

  import: (node, scope, walk) ->
    names, values = node[2], node[3]

    for name in *names
      scope\add_declaration name, pos: node[-1], type: 'import'

    walk {values}, scope

  decorated: (node, scope, walk) ->
    stm, vals = node[2], node[3]

    -- statement modifiers with `if` and `unless` does not open a new scope
    unless vals[1] == 'if' or vals[1] == 'unless'
      scope = scope\open_scope node, 'decorated'
      scope.is_wrapper = true

    walk {stm}, scope
    walk {vals}, scope

  comprehension: (node, scope, walk) ->
    exps, loop = node[2], node[3]

    unless scope.is_wrapper
      scope = scope\open_scope node, 'comprehension'
      scope.is_wrapper = true

    unless loop
      loop = exps
      exps = nil

    -- we walk the loop first, as it's there that the declarations are
    walk {loop}, scope
    walk {exps}, scope if exps

  tblcomprehension: (node, scope, walk) ->
    exps, loop = node[2], node[3]

    unless scope.is_wrapper
      scope = scope\open_scope node, 'tblcomprehension'
      scope.is_wrapper = true

    -- we walk the loop first, as it's there that the declarations are
    unless loop
      loop = exps
      exps = nil

    walk {loop}, scope
    walk {exps}, scope if exps

  class: (node, scope, walk) ->
    name, parent, body = node[2], node[3], node[4]
    scope\add_declaration name, pos: node[-1], type: 'class'

    -- handle implicit return of class, if last node of current scope
    if scope.node[#scope.node] == node
      scope\add_ref name, pos: node[-1]

    walk {parent}, scope
    scope = scope\open_scope node, 'class'
    walk body, scope

  while: (node, scope, walk) ->
    conds, body = node[2], node[3]
    walk {conds}, scope

    cond_scope = scope\open_scope node, 'while'
    walk body, cond_scope if body

  -- if, elseif, unless
  cond_block: (node, scope, walk) ->
    op, conds, body = node[1], node[2], node[3]
    walk {conds}, scope

    cond_scope = scope\open_scope node, op
    walk body, cond_scope if body

    -- walk any following elseifs/elses as necessary
    rest = [n for i, n in ipairs(node) when i > 3]
    if #rest > 0
      walk rest, scope

  else: (node, scope, walk) ->
    body = node[2]
    scope = scope\open_scope node, 'else'
    walk body, scope

}

handlers['if'] = handlers.cond_block
handlers['elseif'] = handlers.cond_block
handlers['unless'] = handlers.cond_block

walk = (tree, scope) ->
  unless tree
    error "nil passed for node: #{debug.traceback!}"

  for node in *tree
    handler = handlers[node[1]]
    if handler
      handler node, scope, walk
    else
      for sub_node in *node
        if type(sub_node) == 'table'
          walk { sub_node }, scope

report_on_scope = (scope, evaluator, inspections = {}) ->

  for name, decl in pairs scope.declared
    continue if scope.used[name]
    if decl.is_exported or scope.exported_from and scope.exported_from < decl.pos
      continue

    if decl.type == 'param'
      continue if evaluator.allow_unused_param(name)
    elseif decl.type == 'loop-var'
      continue if evaluator.allow_unused_loop_variable(name)
    else
      continue if evaluator.allow_unused(name)

    append inspections, {
      msg: "declared but unused - `#{name}`"
      pos: decl.pos or scope.pos,
    }

  for name, node in pairs scope.used
    unless scope.declared[name] or evaluator.allow_global_access(name)
      if name == 'self' or name == 'super'
        if scope.type == 'method' or scope\has_parent('method')
          continue

      append inspections, {
        msg: "accessing global - `#{name}`"
        pos: node.pos or scope.pos,
      }

  for scope in *scope.scopes
    report_on_scope scope, evaluator, inspections

  inspections

format_inspections = (inspections) ->
  chunks = {}
  for inspection in *inspections
    chunk = "line #{inspection.line}: #{inspection.msg}\n"
    chunk ..= string.rep('=', #chunk - 1) .. '\n'
    chunk ..= "> #{inspection.code}\n"
    chunks[#chunks + 1]  = chunk

  table.concat chunks, '\n'

report = (scope, code, opts = {}) ->
  inspections = {}
  evaluator = config.evaluator opts
  report_on_scope scope, evaluator, inspections

  for inspection in *inspections
    line = pos_to_line(code, inspection.pos)
    inspection.line = line
    inspection.code = get_line code, line

  table.sort inspections, (a, b) -> a.line < b.line
  inspections

lint = (code, opts = {}) ->
  tree, err = parse.string code
  return nil, err unless tree
  require('moon').p(tree) if opts.print_tree
  scope = Scope tree
  walk tree, scope
  report scope, code, opts

lint_file = (file, opts = {}) ->
  fh = assert io.open file, 'r'
  code = fh\read '*a'
  fh\close!
  config_file = opts.lint_config or config.config_for(file)
  opts = config_file and config.load_config_from(config_file, file) or {}
  opts.file = file
  lint code, opts

:lint, :lint_file, :format_inspections, :config
