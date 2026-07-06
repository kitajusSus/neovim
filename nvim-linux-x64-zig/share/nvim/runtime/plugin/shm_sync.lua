if vim.g.loaded_shm_sync == 1 then
  return
end
vim.g.loaded_shm_sync = 1

local ffi = require("ffi")

-- Declare FFI functions
ffi.cdef[[
  int shm_sync_init(const char *session_id, const char *lua_cmd);
  void shm_sync_write(const char *data, size_t len);
  int shm_sync_read(char *buf, size_t max_len, size_t *len_out);
  void shm_sync_close(void);
]]

local active_buf = nil
local active_session = nil
local is_updating = false

local M = {}

-- This function is called by the libuv async callback from the Zig background thread
function M.on_update()
  if not active_buf or not vim.api.nvim_buf_is_valid(active_buf) then
    return
  end

  local max_len = 1024 * 1024
  local buf_c = ffi.new("char[?]", max_len)
  local len_out = ffi.new("size_t[1]")

  if ffi.C.shm_sync_read(buf_c, max_len, len_out) == 0 then
    local new_text = ffi.string(buf_c, len_out[0])
    local new_lines = vim.split(new_text, "\n")

    local current_lines = vim.api.nvim_buf_get_lines(active_buf, 0, -1, false)
    local current_text = table.concat(current_lines, "\n")

    if current_text ~= new_text then
      is_updating = true
      vim.api.nvim_buf_set_lines(active_buf, 0, -1, false, new_lines)
      is_updating = false
    end
  end
end

-- Start sync session
function M.start_sync(session_id)
  if active_buf then
    M.stop_sync()
  end

  active_buf = vim.api.nvim_get_current_buf()
  active_session = session_id

  -- Initialize session in Zig with the Lua callback command
  local cmd = "require('shm_sync').on_update()"
  if ffi.C.shm_sync_init(session_id, cmd) ~= 0 then
    vim.api.nvim_err_writeln("SyncBuffer: Failed to initialize shared memory.")
    active_buf = nil
    active_session = nil
    return
  end

  -- Attach to the buffer to write changes
  vim.api.nvim_buf_attach(active_buf, false, {
    on_lines = function(_, _, _, _, _, _)
      if is_updating then return end
      local lines = vim.api.nvim_buf_get_lines(active_buf, 0, -1, false)
      local text = table.concat(lines, "\n")
      ffi.C.shm_sync_write(text, #text)
    end,
    on_detach = function()
      M.stop_sync()
    end
  })

  -- Sync initial content from SHM if it already exists
  M.on_update()

  -- Send initial write to SHM so others get our content if they join later
  local lines = vim.api.nvim_buf_get_lines(active_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  ffi.C.shm_sync_write(text, #text)

  vim.api.nvim_out_write("SyncBuffer: Active session '" .. session_id .. "'\n")
end

-- Stop sync session
function M.stop_sync()
  if active_buf then
    ffi.C.shm_sync_close()
    vim.api.nvim_out_write("SyncBuffer: Closed session '" .. (active_session or "") .. "'\n")
    active_buf = nil
    active_session = nil
  end
end

-- Register module so require('shm_sync') works
package.loaded["shm_sync"] = M

-- Define global Lua function for :lua sync_buffer('session_id')
_G.sync_buffer = function(session_id)
  if not session_id or session_id == "" then
    M.stop_sync()
  else
    M.start_sync(session_id)
  end
end

-- Define Neovim user command: :SyncBuffer <session_id>
vim.api.nvim_create_user_command("SyncBuffer", function(opts)
  local arg = opts.args
  if arg == "stop" or arg == "" then
    M.stop_sync()
  else
    M.start_sync(arg)
  end
end, {
  nargs = 1,
  desc = "Sync buffer via shared memory (use 'stop' to disable)"
})
