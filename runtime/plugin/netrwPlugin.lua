if vim.g.loaded_netrw ~= nil or vim.g.loaded_netrwPlugin ~= nil then
  return
end

vim.cmd.packadd('netrw')
