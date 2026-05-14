require "nvchad.options"

-- add yours here!

-- to enable cursorline!
local o = vim.o
o.cursorlineopt ='both'

vim.opt.relativenumber = true
vim.opt.colorcolumn = "80"

-- Flutter run (toggle terminal + hot reload)
require "configs.flutter"
