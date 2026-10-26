if vim.g.loaded_tarPlugin ~= nil then
  return
end
vim.g.loaded_tarPlugin = 'v32'

local group = vim.api.nvim_create_augroup('tar', { clear = true })

local tarfile_patterns = { 'tarfile::*' }
if vim.fn.has('unix') == 1 then
  table.insert(tarfile_patterns, 'tarfile::*/*')
end

vim.api.nvim_create_autocmd({ 'BufReadCmd', 'FileReadCmd' }, {
  group = group,
  pattern = tarfile_patterns,
  callback = function(args)
    vim.fn['tar#Read'](args.match)
  end,
})

vim.api.nvim_create_autocmd({ 'BufWriteCmd', 'FileWriteCmd' }, {
  group = group,
  pattern = tarfile_patterns,
  callback = function(args)
    vim.fn['tar#Write'](args.match)
  end,
})

local browse_patterns = {
  '*.cbt',
  '*.lrp',
  '*.tar',
  '*.tar.bz2',
  '*.tar.bz3',
  '*.tar.gz',
  '*.tar.lz4',
  '*.tar.lzma',
  '*.tar.xz',
  '*.tar.Z',
  '*.tar.zst',
  '*.tbz',
  '*.tgz',
  '*.tlz4',
  '*.txz',
  '*.tzst',
}

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = browse_patterns,
  callback = function(args)
    vim.fn['tar#Browse'](args.match)
  end,
})
