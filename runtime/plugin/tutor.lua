if vim.g.loaded_tutor_mode_plugin ~= nil then
  return
end
vim.g.loaded_tutor_mode_plugin = 1

vim.api.nvim_create_user_command('Tutor', function(opts)
  require('tutor').tutor_cmd(opts.args)
end, {
  nargs = '?',
  complete = function(arg_lead, cmd_line, cursor_pos)
    return require('tutor').tutor_cmd_complete(arg_lead, cmd_line, cursor_pos)
  end,
})
