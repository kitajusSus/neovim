local vimruntime = vim.env.VIMRUNTIME or vim.fn.expand('$VIMRUNTIME')
if vim.g.loaded_matchit ~= nil or not vim.o.packpath:find(vimruntime, 1, true) then
  return
end

vim.cmd.packadd('matchit')
