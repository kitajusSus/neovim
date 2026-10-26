if vim.g.loaded_remote_plugins then
  return
end
vim.g.loaded_remote_plugins = '/path/to/manifest'

local function get_manifest_path()
  local manifest_env = vim.env.NVIM_RPLUGIN_MANIFEST
  if manifest_env and manifest_env ~= '' then
    return vim.fs.normalize(vim.fn.fnamemodify(manifest_env, ':p'))
  end

  local dest = vim.fn.stdpath('data')
  if dest and dest ~= '' then
    if vim.fn.isdirectory(dest) == 0 and vim.fn.getftype(dest) ~= 'link' then
      vim.fn.mkdir(dest, 'p', tonumber('700', 8))
    end
  end

  return dest .. '/rplugin.vim'
end

local function get_old_manifest_paths()
  local prefix = vim.env.MYVIMRC
  if not prefix or prefix == '' then
    local sn = vim.fn.split(vim.fn.execute('scriptnames'), '\n')
    prefix = vim.fn.matchstr(sn[1] or '', '\\f\\+$')
  end
  local origpath = vim.fn.fnamemodify(vim.fn.expand(prefix, 1), ':h')
    .. '/.'
    .. vim.fn.fnamemodify(prefix, ':t')
    .. '-rplugin~'

  if vim.fn.has('win32') == 0 then
    return { origpath }
  end

  local pseudostdpath = vim.env.LOCALAPPDATA
  if not pseudostdpath or pseudostdpath == '' then
    pseudostdpath = '~/AppData/Local'
  end
  pseudostdpath = vim.fn.fnamemodify(vim.fn.expand(pseudostdpath), ':p')
  local p1 = vim.fn.substitute(pseudostdpath, '[/\\\\]\\=$', '/', '') .. 'nvim/rplugin.vim'
  return { p1, origpath }
end

local function get_manifest()
  local manifest = get_manifest_path()
  if vim.fn.filereadable(manifest) == 0 then
    for _, old_manifest in ipairs(get_old_manifest_paths()) do
      if vim.fn.filereadable(old_manifest) == 1 then
        vim.fn.rename(old_manifest, manifest)
        break
      end
    end
  end
  return manifest
end

local function load_remote_plugins()
  vim.g.loaded_remote_plugins = get_manifest()
  if vim.fn.filereadable(vim.g.loaded_remote_plugins) == 1 then
    vim.cmd.source(vim.fn.fnameescape(vim.g.loaded_remote_plugins))
  end
end

vim.api.nvim_create_user_command('UpdateRemotePlugins', function()
  vim.fn['remote#host#UpdateRemotePlugins']()
end, { bar = true })

if not vim.tbl_contains(vim.v.argv, '--clean') then
  load_remote_plugins()
end
