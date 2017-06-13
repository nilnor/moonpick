{
  whitelist_globals: {
    ["."]: {
    },

    Spookfile: {
      'log_level',
      'watch',
      'on_changed',
      'notify',
      'watch_file',
      'load_spookfile',
    }

    spec: {
      'after_each',
      'async',
      'before_each',
      'context',
      'describe',
      'it',
      'settimeout',
      'setup',
      'spy',
      'teardown',
    },

  }
}
