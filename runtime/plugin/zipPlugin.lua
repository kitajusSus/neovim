if vim.g.loaded_zipPlugin ~= nil then
  return
end
vim.g.loaded_zipPlugin = 'v33'

if vim.g.zipPlugin_ext == nil then
  vim.g.zipPlugin_ext =
    '*.aar,*.apk,*.cbz,*.celzip,*.crtx,*.docm,*.docx,*.dotm,*.dotx,*.ear,*.epub,*.gcsx,*.glox,*.gqsx,*.ja,*.jar,*.kmz,*.odb,*.odc,*.odf,*.odg,*.odi,*.odm,*.odp,*.ods,*.odt,*.otc,*.otf,*.otg,*.oth,*.oti,*.otp,*.ots,*.ott,*.oxt,*.pkpass,*.potm,*.potx,*.ppam,*.ppsm,*.ppsx,*.pptm,*.pptx,*.sldx,*.thmx,*.vdw,*.war,*.whl,*.wsz,*.xap,*.xlam,*.xlsb,*.xlsm,*.xlsx,*.xltm,*.xltx,*.xpi,*.zip'
end

local group = vim.api.nvim_create_augroup('zip', { clear = true })

local zipfile_patterns = { 'zipfile:*' }
if vim.fn.has('unix') == 1 then
  table.insert(zipfile_patterns, 'zipfile:*/*')
end

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = zipfile_patterns,
  callback = function(args)
    vim.fn['zip#Read'](args.match, 1)
  end,
})

vim.api.nvim_create_autocmd('FileReadCmd', {
  group = group,
  pattern = zipfile_patterns,
  callback = function(args)
    vim.fn['zip#Read'](args.match, 0)
  end,
})

vim.api.nvim_create_autocmd({ 'BufWriteCmd', 'FileWriteCmd' }, {
  group = group,
  pattern = zipfile_patterns,
  callback = function(args)
    vim.fn['zip#Write'](args.match)
  end,
})

local browse_patterns = vim.split(vim.g.zipPlugin_ext, ',', { plain = true })

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = group,
  pattern = browse_patterns,
  callback = function(args)
    vim.fn['zip#Browse'](args.match)
  end,
})
