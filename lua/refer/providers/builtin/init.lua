---@class BuiltinProvider
local M = {}

M.commands = require "refer.providers.builtin.commands"
M.buffers = require "refer.providers.builtin.buffers"
M.old_files = require "refer.providers.builtin.old_files"
M.macros = require "refer.providers.builtin.macros"

return M
