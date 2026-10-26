local M = {}

local function get_locale()
  local lang = 'en_US'
  local v_lang = vim.v.lang
  local lc_all = vim.env.LC_ALL or ''
  local lc_messages = vim.env.LC_MESSAGES or ''
  local env_lang = vim.env.LANG or ''

  if v_lang and v_lang:match('%a%a') then
    lang = v_lang
  elseif lc_all:match('%a%a') then
    lang = lc_all
  elseif lc_messages:match('%a%a') or lc_messages == 'C' then
    if lc_messages:match('%a%a') then
      lang = lc_messages
    end
  elseif env_lang:match('%a%a') then
    lang = env_lang
  end
  return vim.split(lang, '_', { plain = true })
end

local function sort_tutors(a, b)
  local mod_a = vim.fn.fnamemodify(a, ':t')
  local mod_b = vim.fn.fnamemodify(b, ':t')
  if mod_a == mod_b then
    return false
  end
  local a_vim = mod_a:sub(1, 4) == 'vim-'
  local b_vim = mod_b:sub(1, 4) == 'vim-'
  if a_vim and not b_vim then
    return true
  elseif b_vim and not a_vim then
    return false
  else
    return mod_a < mod_b
  end
end

function M.setup_vim()
  if vim.g.did_load_ftplugin ~= 1 then
    vim.cmd('filetype plugin on')
  end
  if vim.fn.has('syntax') == 1 then
    if vim.g.syntax_on == nil or vim.g.syntax_on == 0 then
      vim.cmd('syntax on')
    end
  end
end

function M.load_metadata()
  require('nvim.tutor').load_metadata()
end

function M.apply_marks()
  require('nvim.tutor').apply_marks()
end

function M.apply_marks_on_changed()
  require('nvim.tutor').apply_marks_on_changed()
end

local interactive_group = vim.api.nvim_create_augroup('tutor_interactive', { clear = false })

function M.enable_interactive(enable)
  if enable then
    vim.bo.buftype = 'nowrite'
    vim.opt_local.concealcursor:append('inv')
    vim.wo.conceallevel = 2
    require('nvim.tutor').apply_marks()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_clear_autocmds({ group = interactive_group, buffer = bufnr })
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      group = interactive_group,
      buffer = bufnr,
      callback = function()
        require('nvim.tutor').apply_marks_on_changed()
      end,
    })
  else
    vim.cmd([[
      setlocal buftype<
      setlocal concealcursor<
      setlocal conceallevel<
    ]])
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_clear_autocmds({ group = interactive_group, buffer = bufnr })
  end
end

function M.apply_transform()
  if vim.fn.has('win32') == 1 then
    vim.cmd([[silent! %s/{unix:(\(.\{-}\)),win:(\(.\{-}\))}/\2/g]])
  else
    vim.cmd([[silent! %s/{unix:(\(.\{-}\)),win:(\(.\{-}\))}/\1/g]])
  end
  vim.cmd('normal! gg0')
end

function M.folds(lnum)
  lnum = lnum or vim.v.lnum
  local line = vim.fn.getline(lnum)
  local m = line:match('^(#+)')
  if m then
    return '>' .. math.min(#m, 6)
  else
    return '='
  end
end

function M.follow_link(force)
  local syn_ids = vim.fn.synstack(vim.fn.line('.'), vim.fn.col('.'))
  local names = vim.tbl_map(function(id)
    return vim.fn.synIDattr(id, 'name')
  end, syn_ids)
  local stack_s = table.concat(names, '')
  if not stack_s:find('tutorLink') then
    return
  end
  local link_start = vim.fn.searchpairpos('\\[', '', ')', 'nbcW')
  local link_end = vim.fn.searchpairpos('\\[', '', ')', 'ncW')
  if link_start[1] ~= link_end[1] or link_start[1] == 0 then
    return
  end
  local line = vim.fn.getline(link_start[1])
  local link_data = line:sub(link_start[2], link_end[2])
  local target = link_data:match('%((.*)%)')
  if not target then
    return
  end
  if not force and target:match('%*.+%*') then
    vim.fn.cursor(link_start[1], link_end[2])
    vim.fn.search(target, '')
    vim.cmd('normal! ^')
  elseif not force and target:match('^@tutor:') then
    local tut = target:match('^@tutor:(.*)')
    M.tutor_cmd(tut)
  else
    vim.cmd('help ' .. target)
  end
end

function M.mouse_double_click()
  local lnum = vim.fn.line('.')
  if vim.fn.foldclosed(lnum) > -1 then
    vim.cmd('normal! zo')
  else
    local line = vim.fn.getline('.')
    if line:match('^#+%s') and vim.fn.foldlevel(lnum) > 0 then
      vim.cmd('silent normal! zc')
    else
      M.follow_link(false)
    end
  end
end

function M.inject_command()
  local cmd = vim.fn.getline('.'):gsub('^%s*', '')
  vim.cmd(cmd)
  vim.cmd('redraw')
  vim.api.nvim_echo({
    { 'tutor: ran', 'WarningMsg' },
    { ' ' },
    { cmd, 'Statement' },
  }, false, {})
end

function M.set_normal_mappings()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.keymap.set('n', '<CR>', function()
    M.follow_link(false)
  end, { buffer = bufnr, silent = true })
  vim.keymap.set('n', '<2-LeftMouse>', function()
    M.mouse_double_click()
  end, { buffer = bufnr, silent = true })
  vim.keymap.set('n', '>>', function()
    M.inject_command()
  end, { buffer = bufnr })
end

function M.glob_tutorials(name, locale)
  locale = locale or get_locale()[1]
  local rtp_paths = vim.api.nvim_list_runtime_paths()
  local rtp = {}
  for _, p in ipairs(rtp_paths) do
    table.insert(rtp, vim.fn.escape(vim.fs.normalize(p), ','))
  end
  local rtp_str = table.concat(rtp, ',')

  local tutors = vim.fn.globpath(rtp_str, 'tutor/' .. name .. '.tutor', 1, 1)
  local locale_tutors =
    vim.fn.globpath(rtp_str, 'tutor/' .. locale .. '/' .. name .. '.tutor', 1, 1)
  if #locale_tutors == 0 then
    locale_tutors = vim.fn.globpath(rtp_str, 'tutor/en/' .. name .. '.tutor', 1, 1)
  end
  vim.list_extend(tutors, locale_tutors)

  table.sort(tutors, sort_tutors)
  local unique = {}
  local seen = {}
  for _, tut in ipairs(tutors) do
    if not seen[tut] then
      seen[tut] = true
      table.insert(unique, tut)
    end
  end
  return unique
end

function M.tutor_cmd_complete(lead, line, pos)
  local tutors = M.glob_tutorials('*', get_locale()[1])
  local names = {}
  local seen = {}
  for _, path in ipairs(tutors) do
    local n = vim.fn.fnamemodify(path, ':t:r')
    if not seen[n] then
      seen[n] = true
      table.insert(names, n)
    end
  end
  return names
end

function M.tutor_cmd(name)
  name = name or ''
  if name:find('%s') then
    vim.api.nvim_echo({ { 'Only one argument accepted (check spaces)' } }, true, {})
    return
  end

  local tutor_name = name
  if tutor_name == '' then
    tutor_name = 'vim-01-beginner.tutor'
  end

  if tutor_name:match('%.tutor$') then
    tutor_name = vim.fn.fnamemodify(tutor_name, ':r')
  end

  local tutors = M.glob_tutorials(tutor_name, get_locale()[1])

  if #tutors == 0 then
    vim.api.nvim_echo({ { 'No tutorial with that name found' } }, true, {})
    return
  end

  local to_open
  if #tutors == 1 then
    to_open = tutors[1]
  else
    local candidates = { 'Several tutorials with that name found. Select one:' }
    local loc = get_locale()[1]
    for idx, candidate in ipairs(tutors) do
      local display = vim.fn.fnamemodify(candidate, ':h:h:t')
        .. '/'
        .. loc
        .. '/'
        .. vim.fn.fnamemodify(candidate, ':t')
      table.insert(candidates, idx .. '. ' .. display)
    end
    local tutor_to_open = vim.fn.inputlist(candidates)
    if tutor_to_open < 1 or tutor_to_open > #tutors then
      return
    end
    to_open = tutors[tutor_to_open]
  end

  local tutor_file_og = to_open
  local tutor_file_tmp = vim.fn.tempname() .. '.' .. vim.fn.fnamemodify(tutor_file_og, ':t')
  vim.fn.filecopy(tutor_file_og, tutor_file_tmp)

  M.setup_vim()
  vim.cmd('drop ' .. vim.fn.fnameescape(tutor_file_tmp))
  vim.b.tutor_file = tutor_file_og
  M.load_metadata()
  M.enable_interactive(true)
  M.apply_transform()
end

return M
