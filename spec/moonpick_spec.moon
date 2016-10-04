-- Copyright 2016 Nils Nordman <nino@nordman.org>
-- License: MIT (see LICENSE.md at the top-level directory of the distribution)

moonpick = require 'moonpick'

describe 'moonpick', ->
  clean = (code) ->
    initial_indent = code\match '^([ \t]*)%S'
    code = code\gsub '\n\n', "\n#{initial_indent}\n"
    lines = [l\gsub("^#{initial_indent}", '') for l in code\gmatch('[^\n]+')]
    code = table.concat lines, '\n'
    code = code\match '^%s*(.-)%s*$'
    code .. '\n'

  lint = (code, opts) ->
    inspections = assert moonpick.lint code, opts
    res = {}

    for i in *inspections
      {:line, :msg} = i
      res[#res + 1] = :line, :msg

    res

  describe 'unused variables', ->
    it 'detects unused variables', ->
      code = 'used = 2\nfoo = 2\nused'
      res = lint code, {}
      assert.same {
        {line: 2, msg: 'declared but unused - `foo`'}
      }, res

    it 'handles multiple assignments', ->
      code = 'a, b = 1, 2\na'
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `b`'}
      }, res

    it 'does not report variable used in a different scope', ->
      code = clean [[
        a = 1
        ->
          a + 1
      ]]
      res = lint code, {}
      assert.same {}, res

    it 'detects function scoped, unused variables', ->
      code = clean [[
        x = -> a = 1
        x = -> a = 1
        x
      ]]
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `a`'}
        {line: 2, msg: 'declared but unused - `a`'}
      }, res

    it 'detects control flow scoped, unused variables', ->
      code = clean [[
        if _G.foo
          x = 2
        elseif _G.zed
          x = 1
        else
          x = 1
        unless _G.bar
          x = 3
        x
      ]]
      res = lint code, {}
      assert.same {
        {line: 2, msg: 'declared but unused - `x`'}
        {line: 4, msg: 'declared but unused - `x`'}
        {line: 6, msg: 'declared but unused - `x`'}
        {line: 8, msg: 'declared but unused - `x`'}
        {line: 9, msg: 'accessing global - `x`'}
      }, res

    it 'detects while scoped unused variables', ->
      code = clean [[
        while true
          x = 1
          break
      ]]
      res = lint code, {}
      assert.same {
        {line: 2, msg: 'declared but unused - `x`'}
      }, res

    it 'accounts for implicit returns', ->
      code = clean [[
        x = 1
        ->
          y = 1
          y
        x
       ]]
      res = lint code, {}
      assert.same {}, res

    it 'detects unused function parameters if requested', ->
      code = '(foo) -> 2'
      res = lint code, report_params: true
      assert.same {
        {line: 1, msg: 'declared but unused - `foo`'}
      }, res

    it 'detects usages in parameter lists', ->
      code = clean [[
      x = 1
      (v = x)->
        v
      ]]
      res = lint code
      assert.same {}, res

    it 'does not complain about varargs', ->
      code = clean [[
        (...) ->
          ...
       ]]
      res = lint code, {}
      assert.same {}, res

    it 'respects a given whitelist_params', ->
      code = clean '(x) -> 1'
      res = lint code, { whitelist_params: {'x'} }
      assert.same {}, res

    it 'respects a given whitelist_loop_variables', ->
      code = clean 'for x in *{1,2}\n  _G.other = 1'
      res = lint code, { whitelist_loop_variables: {'x'} }
      assert.same {}, res

    it 'does not complain about @variables in methods', ->
      code = clean [[
        class Foo
          new: (@bar) =>
          other: (@zed) =>

        Foo
      ]]
      res = lint code
      assert.same {}, res

    it 'detects unused class definitions', ->
      code = clean [[
        class Foo extends _G.Bar
          new: =>

        {}
        ]]
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `Foo`'}
      }, res

    it 'detects implicit returns of class definitions', ->
      code = clean [[
        class Foo
          new: =>
        ]]
      res = lint code, {}
      assert.same {
      }, res

    it 'detects dotted assignment references', ->
      code = clean [[
        (arg) ->
          arg.foo = .zed
      ]]
      res = lint code
      assert.same {}, res

    it 'handles local declarations', ->
      code = clean [[
        local x, y
        ->
          x = 2
          y = 1
          y + x
      ]]
      res = lint code
      assert.same {}, res

    it 'handles export declarations', ->
      code = clean [[
        export foo
        ->
          foo = 2
        y = 1
        export zed = ->
          y + 2
      ]]
      res = lint code
      assert.same {}, res

    it 'handles wildcard export declarations', ->
      code = clean [[
        x = 1
        export *
        y = 2
      ]]
      res = lint code
      assert.same {
        {line: 1, msg: 'declared but unused - `x`'}
      }, res

    it 'detects indexing references', ->
      code = clean [[
        (foo) ->
          _G[foo] = 2
      ]]
      res = lint code
      assert.same {}, res

    it 'detects unused imports', ->
      code = 'import foo from _G.bar'
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `foo`'}
      }, res

    it 'detects usages in import source lists', ->
      code = clean [[
        ffi = require 'ffi'
        import C from ffi
        C
      ]]
      res = lint code
      assert.same {}, res

    it 'detects unused decomposition variables', ->
      code = clean [[
      {:foo} = _G.bar
      {bar: other} = _G.zed
      ]]
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `foo`'}
        {line: 2, msg: 'declared but unused - `other`'}
      }, res

      code = '{:foo, :bar} = _G.bar'
      res = lint code, {}
      assert.equal 2, #res

    it 'detects unused variables in ordinary loops', ->
      code = clean [[
        for foo = 1,10
          _G.other!

        for foo = 1,10
          _G.other foo
      ]]
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `foo`'}
      }, res

    it 'detects unused variables in for each loops', ->
      code = clean [[
        for foo in *{2, 3}
          _G.other!

      ]]
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'declared but unused - `foo`'}
      }, res

    it 'does not warn for used vars in decorated statements', ->
      code = clean [[
        _G[a] = nil for a in *_G.list
        ]]
      res = lint code, {}
      assert.same {}, res

    it 'detects variable usages correctly in comprehensions', ->
      code = clean [[
        [x * 2 for x in *_G.foo]
        ]]
      res = lint code, {}
      assert.same {}, res

    it 'detects variable usages correctly in for comprehensions', ->
      code = clean [[
      [tostring(l) for l = 1, 100]
      ]]
      res = lint code
      assert.same {}, res

    it 'detects variable usages correctly in comprehensions 2', ->
      code = clean [[
        [name for name in pairs _G.foo]
      ]]
      res = lint code
      assert.same {}, res

    it 'detects variable usages correctly in hash comprehensions', ->
      code = clean [[
        {k, _G.foo[k] for k in *{1,2}}
      ]]
      res = lint code
      assert.same {}, res

  describe 'undeclared access', ->
    it 'detected undeclared accesses', ->
      code = 'foo!'
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'accessing global - `foo`'}
      }, res

    it 'detected undeclared accesses for chained expressions', ->
      code = 'foo.x'
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'accessing global - `foo`'}
      }, res

    it 'reports each undeclared usage separately', ->
      code = clean [[
        x 1
        x 2
      ]]
      res = lint code, {}
      assert.same {
        {line: 1, msg: 'accessing global - `x`'}
        {line: 2, msg: 'accessing global - `x`'}
      }, res

    it 'includes built-ins in the global whitelist', ->
      code = clean [[
        x = tostring(_G.foo)
        y = table.concat {}, '\n'
        x + y
      ]]
      res = lint code
      assert.same {}, res

    it 'allows access to self and super in methods', ->
      code = clean [[
        class Foo
          meth: =>
            self.bar!
            super!
      ]]
      res = lint code
      assert.same {}, res

    it 'allows access to self in methods and sub scopes thereof', ->
      code = clean [[
        class Foo
          meth: =>
            if true
              self.bar!
      ]]
      res = lint code
      assert.same {}, res

    it 'disallows access to self in functions', ->
      code = clean [[
        ->
          self.bar!
      ]]
      res = lint code
      assert.same {
        {line: 2, msg: 'accessing global - `self`'}
      }, res

    it 'handles variabled assigned with statement modifiers correctly', ->
      code = clean [[
        x = _G.foo if true
        x
      ]]
      res = lint code
      assert.same {}, res

      code = clean [[
        x = _G.foo unless false
        x
      ]]
      res = lint code
      assert.same {}, res

    it 'handles variabled assigned with statement modifiers correctly', ->
      code = clean [[
        x or= _G.foo
        y or= _G.bar\zed!
        x + y
      ]]
      res = lint code
      assert.same {}, res

    it 'handles variables assigned with decomposition correctly', ->
      code = clean [[
        {foo, bar} = _G.zed
        foo + bar
      ]]
      res = lint code
      assert.same {}, res

    it 'detects class parent references', ->
      code = clean [[
        import Base from _G
        class I extends Base
      ]]
      res = lint code
      assert.same {}, res

    it 'handles non-prefixed member access', ->
      code = clean [[
        class Foo
          bar: (@x = 'zed') =>
            x
      ]]
      res = lint code
      assert.same {}, res

    it 'handles loop modified statements', ->
      code = clean [[
        _G.foo[t] = true for t in pairs {}
        t! for t in *{}
        _G.foo += i for i = 1, 10
      ]]
      res = lint code
      assert.same {}, res

    it 'foo2', ->
      code = clean [[
        if _G.data and _G.data.tokens
          _G.data.tokens[token] = true for token in pairs _G.tokens
      ]]
      res = lint code
      assert.same {}, res

    it 'handles while scoped unused variables', ->
      code = clean [[
        while true
          x = 1
          if x
            break
        x
      ]]
      res = lint code, {}
      assert.same {
        {line: 5, msg: 'accessing global - `x`'}
      }, res

  describe 'format_inspections(inspections)', ->
    it 'returns a string representation of inspections', ->
      code = clean [[
      {:foo} = _G.bar
      {bar: other} = _G.zed
      ]]
      inspections = assert moonpick.lint code, {}
      assert.same clean([[
        line 1: declared but unused - `foo`
        ===================================
        > {:foo} = _G.bar

        line 2: declared but unused - `other`
        =====================================
        > {bar: other} = _G.zed
      ]]), moonpick.format_inspections(inspections)

  describe 'shadowing warnings', ->
    it 'detects shadowing outer variables in for each', ->
      code = clean [[
        x = 2
        for x in *{1,2}
          _G.other x
        x
      ]]
      res = lint code, {}
      assert.same {
        {line: 2, msg: 'shadowing outer variable - `x`'}
      }, res

    it 'detects shadowing using local statements', ->
      code = clean [[
        x = 2
        ->
          local x
          x = 2
          x * 2
        x
      ]]
      res = lint code, {}
      assert.same {
        {line: 3, msg: 'shadowing outer variable - `x`'}
      }, res

    it 'understand lexical scoping', ->
      code = clean [[
        for x in *{1,2}
          _G.other x
        x = 2 -- defined after previous declaration
        x
      ]]
      res = lint code, {}
      assert.same {}, res

    it 'rvalue declaration values generally does not shadow lvalues', ->
      code = clean [[
        x = { -- assignment lvalue target
          f: (x) -> -- this is part of the rvalue
        }
        x
      ]]
      res = lint code, {}
      assert.same {}, res

    it 'implicitly local lvalue declarations are recognized (i.e. fndefs)', ->
      code = clean [[
        f = (x) -> x + f(x + 1)
        f
      ]]
      res = lint code, {}
      assert.same {}, res

    it 'does not complain about foreach comprehension vars shadowing target', ->
      code = clean [[
        for x in *[x for x in *_G.foo when x != 'bar' ]
          x!
      ]]
      res = lint code, {}
      assert.same {}, res

    it 'handles scope shadowing and unused variables correctly', ->
      code = clean [[
        (a) ->
          [ { a, b } for a, b in pairs {} ]
      ]]
      res = lint code, report_params: true
      assert.same {
        {line: 1, msg: 'declared but unused - `a`'},
        {line: 2, msg: 'shadowing outer variable - `a`'}
      }, res
