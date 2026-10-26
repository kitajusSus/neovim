local M = {}

local have = {}

local function check(cmd)
  local name = cmd:match('^(%S+)')
  if not name then
    return false
  end
  if have[name] ~= nil then
    return have[name]
  end

  local ok_safe, f = pcall(vim.fn['dist#vim#IsSafeExecutable'], 'gzip', name)
  if not ok_safe then
    f = 1
  end
  if f == 0 or f == false then
    vim.api.nvim_echo({ { 'Warning: NOT executing ' .. name .. ' from current directory!', 'ErrorMsg' } }, true, {})
  end

  local e = vim.fn.executable(name)
  local is_exec = (e == 1)
  if e < 0 then
    local r = vim.fn.system(name .. ' --version')
    is_exec = (not r:find('not found') and r ~= '')
  end

  local res = (is_exec and (f == 1 or f == true))
  have[name] = res
  return res
end

local function set_compression(line)
  if type(line) ~= 'string' or #line < 9 then
    return
  end
  local cm = line:byte(3)
  if cm == 8 then
    local xfl = line:byte(9)
    if xfl == 2 then
      vim.b.gzip_comp_arg = '-9'
    elseif xfl == 4 then
      vim.b.gzip_comp_arg = '-1'
    end
  end
end

local function samedir_tempname(name)
  local tmp = vim.fn.tempname()
  return vim.fn.fnamemodify(name, ':p:h') .. '/' .. vim.fn.fnamemodify(tmp, ':h:t') .. vim.fn.fnamemodify(tmp, ':t')
end

local function tempname(name)
  local fn = vim.fn.fnamemodify(name, ':r')
  if vim.fn.filereadable(fn) == 0 and vim.fn.isdirectory(fn) == 0 then
    return fn
  end
  return samedir_tempname(name)
end

function M.read(cmd)
  if not check(cmd) then
    return
  end

  vim.b.gzip_comp_arg = nil
  if cmd:sub(1, 1) == 'g' then
    set_compression(vim.fn.getline(1))
  end

  local pm_save = vim.o.patchmode
  vim.o.patchmode = ''
  local cpo_save = vim.o.cpoptions
  vim.opt.cpoptions:remove({ 'a', 'A' })
  local ma_save = vim.bo.modifiable
  vim.bo.modifiable = true
  local write_save = vim.o.write
  vim.o.write = true
  local fen_save = vim.wo.foldenable
  vim.wo.foldenable = false

  local line_start = vim.fn.line("'[")
  local line_end = vim.fn.line("']")
  local line_total = vim.fn.line('$')
  local empty = (line_start == 1 and line_end == line_total)

  local tmp = vim.fn.tempname()
  local ext = vim.fn.expand('<afile>:e')
  local tmpe = tmp .. '.' .. ext
  local tmp_esc = vim.fn.fnameescape(tmp)
  local tmpe_esc = vim.fn.fnameescape(tmpe)

  vim.cmd("silent '[,']w " .. tmpe_esc)
  vim.fn.system(cmd .. ' ' .. vim.fn.shellescape(tmpe))

  local ok
  if vim.fn.filereadable(tmp) == 0 then
    vim.api.nvim_echo({ { 'Error: Could not read uncompressed file', 'ErrorMsg' } }, true, {})
    ok = 0
  else
    ok = 1
    local l = line_start - 1
    vim.cmd("lockmarks '[,']d _")
    vim.bo.binary = false
    if empty then
      vim.cmd('silent lockmarks ' .. l .. 'r ++edit ' .. tmp_esc)
    else
      vim.cmd('silent lockmarks ' .. l .. 'r ' .. tmp_esc)
    end

    if empty then
      vim.cmd('silent $delete _')
      vim.cmd('1')
    end

    vim.fn.delete(tmp)
    vim.cmd('silent! bwipe ' .. tmp_esc)
    vim.cmd('silent! bwipe ' .. tmpe_esc)
  end

  vim.b.uncompressOk = ok

  vim.o.patchmode = pm_save
  vim.o.cpoptions = cpo_save
  vim.bo.modifiable = ma_save
  vim.o.write = write_save
  vim.wo.foldenable = fen_save

  if ok == 1 and empty then
    local fname = vim.fn.fnameescape(vim.fn.expand('%:r'))
    local cur_file = vim.fn.expand('%')
    local ufile = vim.fn.undofile(cur_file)
    if vim.fn.filereadable(ufile) == 1 then
      vim.cmd('sil rundo ' .. vim.fn.fnameescape(ufile))
    end
    if vim.o.verbose >= 8 then
      vim.cmd('doau BufReadPost ' .. fname)
    else
      vim.cmd('silent! doau BufReadPost ' .. fname)
    end
  end
end

function M.write(cmd)
  local uncompressOk = vim.b.uncompressOk
  if uncompressOk ~= nil and (uncompressOk == 0 or uncompressOk == false) then
    vim.api.nvim_echo({
      { 'Not compressing file because uncompress failed; reset b:uncompressOk to compress anyway' },
    }, true, {})
  elseif check(cmd) then
    local nm = vim.fn.resolve(vim.fn.expand('<afile>'))
    local nmt = tempname(nm)
    if vim.fn.rename(nm, nmt) == 0 then
      local comp_arg = vim.b.gzip_comp_arg
      if comp_arg and comp_arg ~= '' then
        vim.fn.system(cmd .. ' ' .. comp_arg .. ' -- ' .. vim.fn.shellescape(nmt))
      else
        vim.fn.system(cmd .. ' -- ' .. vim.fn.shellescape(nmt))
      end
      vim.fn.rename(nmt .. '.' .. vim.fn.expand('<afile>:e'), nm)
    end
  end
end

function M.appre(cmd)
  if check(cmd) then
    local nm = vim.fn.expand('<afile>')
    vim.b.gzip_comp_arg = nil
    if cmd:sub(1, 1) == 'g' then
      local first_line = vim.fn.readfile(nm, 'b', 1)
      if first_line and #first_line > 0 then
        set_compression(first_line[1])
      end
    end

    local nmt = samedir_tempname(nm)
    local nmte = nmt .. '.' .. vim.fn.expand('<afile>:e')
    if vim.fn.rename(nm, nmte) == 0 then
      if vim.o.patchmode ~= '' and vim.fn.getfsize(nm .. vim.o.patchmode) == -1 then
        vim.fn.system(cmd .. ' -c -- ' .. vim.fn.shellescape(nmte) .. ' > ' .. vim.fn.shellescape(nmt))
        vim.fn.rename(nmte, nm .. vim.o.patchmode)
      else
        vim.fn.system(cmd .. ' -- ' .. vim.fn.shellescape(nmte))
      end
      vim.fn.rename(nmt, nm)
    end
  end
end

return M
