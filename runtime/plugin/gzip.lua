if vim.g.loaded_gzip ~= nil or vim.fn.exists('#BufReadPre#*.gz') == 1 then
  return
end
vim.g.loaded_gzip = 1

local group = vim.api.nvim_create_augroup('gzip', { clear = true })

vim.api.nvim_create_autocmd({ 'BufReadPre', 'FileReadPre' }, {
  group = group,
  pattern = {
    '*.gz',
    '*.bz2',
    '*.bz3',
    '*.Z',
    '*.lzma',
    '*.xz',
    '*.lz',
    '*.zst',
    '*.br',
    '*.lzo',
    '*.lz4',
  },
  command = 'setlocal bin',
})

local formats = {
  { ext = '*.br',   read = 'brotli -d --rm', write = 'brotli --rm',     appre = 'brotli -d --rm' },
  { ext = '*.bz2',  read = 'bzip2 -d',       write = 'bzip2',           appre = 'bzip2 -d' },
  { ext = '*.bz3',  read = 'bzip3 -d',       write = 'bzip3',           appre = 'bzip3 -d' },
  { ext = '*.gz',   read = 'gzip -dn',       write = 'gzip',            appre = 'gzip -dn' },
  { ext = '*.lz',   read = 'lzip -d',        write = 'lzip',            appre = 'lzip -d' },
  { ext = '*.lz4',  read = 'lz4 -d -q --rm', write = 'lz4 -q --rm',     appre = 'lz4 -d -q --rm', post = 'lz4 --rm' },
  { ext = '*.lzma', read = 'lzma -d',        write = 'lzma -z',         appre = 'lzma -d' },
  { ext = '*.lzo',  read = 'lzop -d -U',     write = 'lzop -U',         appre = 'lzop -d -U' },
  { ext = '*.xz',   read = 'xz -d',          write = 'xz -z',           appre = 'xz -d' },
  { ext = '*.Z',    read = 'uncompress',     write = 'compress -f',     appre = 'uncompress' },
  { ext = '*.zst',  read = 'zstd -d --rm',   write = 'zstd --rm',       appre = 'zstd -d --rm' },
}

for _, fmt in ipairs(formats) do
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'FileReadPost' }, {
    group = group,
    pattern = fmt.ext,
    callback = function()
      require('gzip').read(fmt.read)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileWritePost' }, {
    group = group,
    pattern = fmt.ext,
    callback = function()
      require('gzip').write(fmt.write)
    end,
  })

  vim.api.nvim_create_autocmd('FileAppendPre', {
    group = group,
    pattern = fmt.ext,
    callback = function()
      require('gzip').appre(fmt.appre)
    end,
  })

  vim.api.nvim_create_autocmd('FileAppendPost', {
    group = group,
    pattern = fmt.ext,
    callback = function()
      require('gzip').write(fmt.post or fmt.write)
    end,
  })
end
