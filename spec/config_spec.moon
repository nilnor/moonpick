-- Copyright 2016 Nils Nordman <nino@nordman.org>
-- License: MIT (see LICENSE.md at the top-level directory of the distribution)

config = require 'moonpick.config'
lfs = require 'lfs'
dir = require 'pl.dir'

describe 'config', ->

  write_file = (path, contents) ->
    f = assert io.open(path, 'wb')
    f\write contents
    assert f\close!

  describe 'config_for(file)', ->
    local base_dir

    before_each ->
      base_dir = os.tmpname!
      assert(os.remove(base_dir)) if lfs.attributes(base_dir)
      assert(lfs.mkdir(base_dir))

    after_each -> dir.rmtree(base_dir)

    it 'returns the first available lint_config by moving up the path', ->
      assert(lfs.mkdir("#{base_dir}/sub"))
      ex_file = "#{base_dir}/sub/file.moon"

      in_dir_cfg = "#{base_dir}/sub/lint_config.lua"
      write_file in_dir_cfg, '{}'
      assert.equal in_dir_cfg, config.config_for(ex_file)
      os.remove(in_dir_cfg)

      parent_dir_cfg = "#{base_dir}/lint_config.lua"
      write_file parent_dir_cfg, '{}'
      assert.equal parent_dir_cfg, config.config_for(ex_file)

    it 'supports and prefers moonscript config files if available', ->
      assert(lfs.mkdir("#{base_dir}/sub"))
      ex_file = "#{base_dir}/sub/file.moon"

      lua_cfg = "#{base_dir}/lint_config.lua"
      moon_cfg = "#{base_dir}/lint_config.moon"
      write_file lua_cfg, '{}'
      write_file moon_cfg, '{}'

      assert.equal moon_cfg, config.config_for(ex_file)
      os.remove(moon_cfg)
      assert.equal lua_cfg, config.config_for(ex_file)

  describe 'load_config_from(config, file)', ->
    sorted = (t) ->
      table.sort t
      t

    it 'loads the relevant settings for <file> from <config>', ->
      cfg = {
        whitelist_globals: {
          ["."]: { 'foo' },
          test: { 'bar' }
          other: { 'zed' }
        }
      }
      assert.same {
        whitelist_globals: sorted { 'bar', 'foo' }
      }, config.load_config_from(cfg, '/test/foo.moon')

    it 'loads <config> as a file when passed as a string', ->
      path = os.tmpname!
      write_file path, [[
      return {
        whitelist_globals = {
          test = {'bar'}
        }
      }
      ]]
      assert.same {
        whitelist_globals: { 'bar' }
      }, config.load_config_from(path, '/test/foo.moon')

  describe 'evaluator(config)', ->
    evaluator = config.evaluator

    describe 'allow_unused_param(p)', ->
      it 'generally returns false', ->
        assert.is_false evaluator({}).allow_unused_param('foo')

      it 'returns true if config.report_params is false', ->
        assert.is_true evaluator(report_params: false).allow_unused_param('foo')

      it 'returns true if config.whitelist_params contains <p>', ->
        whitelist_params = {'foo'}
        assert.is_true evaluator(:whitelist_params).allow_unused_param('foo')

      it 'supports patterns', ->
        whitelist_params = {'^a+'}
        assert.is_true evaluator(:whitelist_params).allow_unused_param('aardwark')

      it 'defaults to white listings params starting with an underscore', ->
        for sym in *{'_', '_foo', '_bar2'}
          assert.is_true evaluator().allow_unused_param(sym)

    describe 'allow_unused_loop_variable(p)', ->
      it 'generally returns false', ->
        assert.is_false evaluator({}).allow_unused_loop_variable('foo')

      it 'returns true if config.report_loop_variables is false', ->
        assert.is_true evaluator(report_loop_variables: false).allow_unused_loop_variable('foo')

      it 'returns true if config.whitelist_loop_variables contains <p>', ->
        whitelist_loop_variables = {'foo'}
        assert.is_true evaluator(:whitelist_loop_variables).allow_unused_loop_variable('foo')

      it 'supports patterns', ->
        whitelist_loop_variables = {'^a+'}
        assert.is_true evaluator(:whitelist_loop_variables).allow_unused_loop_variable('aardwark')

      it 'defaults to white listings params starting with an underscore', ->
        for sym in *{'_', '_foo', '_bar2'}
          assert.is_true evaluator().allow_unused_loop_variable(sym)

    describe 'allow_global_access(p)', ->
      it 'generally returns false', ->
        assert.is_false evaluator({}).allow_global_access('foo')

      it 'returns true if config.whitelist_globals contains <p>', ->
        whitelist_globals = {'foo'}
        assert.is_true evaluator(:whitelist_globals).allow_global_access('foo')

      it 'supports patterns', ->
        whitelist_globals = {'^a+'}
        assert.is_true evaluator(:whitelist_globals).allow_global_access('aardwark')

      it 'always includes whitelisting of builtins', ->
        for sym in *{'require', '_G', 'tostring'}
          assert.is_true evaluator().allow_global_access(sym)

        whitelist_globals = {'foo'}
        assert.is_true evaluator(:whitelist_globals).allow_global_access('table')



