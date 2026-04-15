
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.dart",
  desc = "Flutter hot-reload: send 'r' to existing terminal on dart save",
  callback = function()
    -- Walk every buffer, find one with buftype=terminal
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
        local chan = vim.b[buf].terminal_job_id
        if chan and chan > 0 then
          vim.api.nvim_chan_send(chan, "r")
          return  -- stop after the first one found
        end
      end
    end
    -- Only warn if no terminal exists at all
    vim.notify("[dart] No terminal found — open one with <A-h>", vim.log.levels.WARN)
  end,
})



-------------------------------------------------------------------------------



-- local M = {}
--
-- local term_buf = nil -- buffer handle
-- local term_job = nil -- job id
--
-- -- Check if any loaded buffer is a .dart file
-- local function has_dart_buffer()
--   for _, buf in ipairs(vim.api.nvim_list_bufs()) do
--     if vim.api.nvim_buf_is_loaded(buf) then
--       local name = vim.api.nvim_buf_get_name(buf)
--       if name:match "%.dart$" then
--         return true
--       end
--     end
--   end
--   return false
-- end
--
-- -- Check if the terminal buffer is currently visible in any window
-- local function term_is_visible()
--   if term_buf == nil or not vim.api.nvim_buf_is_valid(term_buf) then
--     return false
--   end
--   for _, win in ipairs(vim.api.nvim_list_wins()) do
--     if vim.api.nvim_win_get_buf(win) == term_buf then
--       return true
--     end
--   end
--   return false
-- end
--
-- -- Open terminal in a bottom split (or re-show it if hidden)
-- local function open_flutter_terminal()
--   if term_buf ~= nil and vim.api.nvim_buf_is_valid(term_buf) then
--     vim.cmd "botright split"
--     vim.api.nvim_win_set_height(0, 20)
--     vim.api.nvim_win_set_buf(0, term_buf)
--     vim.cmd "wincmd p"
--   else
--     -- Save current window before splitting
--     local prev_win = vim.api.nvim_get_current_win()
--
--     vim.cmd "botright split"
--     vim.api.nvim_win_set_height(0, 20)
--
--     -- Create a new empty buffer for the terminal
--     local buf = vim.api.nvim_create_buf(false, true)
--     vim.api.nvim_win_set_buf(0, buf)
--
--     term_job = vim.fn.jobstart("zsh", {
--       term = true,
--       buf = buf,
--       on_exit = function()
--         term_job = nil
--         term_buf = nil
--       end,
--     })
--
--     term_buf = buf
--
--     -- Return focus to original window
--     vim.api.nvim_set_current_win(prev_win)
--   end
-- end
--
-- -- Toggle: hide if visible, show if hidden
-- function M.flutter_run_toggle()
--   if not has_dart_buffer() then
--     vim.notify("FlutterRun: no .dart file in buffer", vim.log.levels.WARN)
--     return
--   end
--
--   if term_is_visible() then
--     -- Close the window showing the terminal (keep buffer alive)
--     for _, win in ipairs(vim.api.nvim_list_wins()) do
--       if vim.api.nvim_win_get_buf(win) == term_buf then
--         vim.api.nvim_win_close(win, false)
--         break
--       end
--     end
--   else
--     open_flutter_terminal()
--   end
-- end
--
-- -- Hot reload: send "r" to the running flutter process
-- function M.flutter_hot_reload()
--   if term_job == nil then
--     return
--   end
--   vim.api.nvim_chan_send(term_job, "r")
-- end
--
-- -- Register :FlutterRun only when a .dart file is active
-- local function maybe_register_command(buf)
--   local name = vim.api.nvim_buf_get_name(buf)
--   if name:match "%.dart$" then
--     vim.api.nvim_buf_create_user_command(buf, "FlutterRun", function()
--       M.flutter_run_toggle()
--     end, { desc = "Toggle Flutter run terminal" })
--   end
-- end
--
-- -- Autocommands
-- local group = vim.api.nvim_create_augroup("FlutterDev", { clear = true })
--
-- -- Register :FlutterRun on every .dart buffer open
-- vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd" }, {
--   group = group,
--   pattern = "*.dart",
--   callback = function(ev)
--     maybe_register_command(ev.buf)
--   end,
-- })
--
-- -- Hot reload on save
-- vim.api.nvim_create_autocmd("BufWritePost", {
--   group = group,
--   pattern = "*.dart",
--   callback = function()
--     M.flutter_hot_reload()
--   end,
-- })
--
--
-- return M
