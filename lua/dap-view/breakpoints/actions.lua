local state = require("dap-view.state")
local util = require("dap-view.views.util")

local M = {}

---@param line integer
---@param switchbuffun? dapview.SwitchBufFun
M.jump = function(line, switchbuffun)
    local entry = state.breakpoint_entries_by_line[line]

    -- Custom breakpoints without a resolved source location cannot be jumped to.
    if entry and entry.remove and not (entry.path and entry.lnum) then
        return
    end

    local lnum = state.breakpoint_lines_by_line[line]
    local path = state.breakpoint_paths_by_line[line]

    util.jump_to_location(path, lnum, nil, switchbuffun)
end

-- From https://github.com/ibhagwan/fzf-lua/blob/9a1f4b6f9e37d6fad6730301af58c29b00d363f8/lua/fzf-lua/actions.lua#L1079-L1101
---@param line integer
M.remove = function(line)
    local entry = state.breakpoint_entries_by_line[line]
    if not entry then
        return
    end

    -- Custom breakpoints provide their own delete callback
    if entry.remove then
        entry.remove()
        return
    end

    -- Native source breakpoint
    local dap_breakpoints = require("dap.breakpoints")

    local lnum = state.breakpoint_lines_by_line[line]
    local path = state.breakpoint_paths_by_line[line]

    local bufnr = util.get_bufnr_from_path(path)
    if bufnr == nil then
        return
    end

    dap_breakpoints.remove(bufnr, lnum)

    local session = require("dap").session()

    if session and bufnr then
        local breapoints = dap_breakpoints.get()

        -- If all BPs were removed from a buffer we must clear the buffer by sending an empty table in the bufnr index
        breapoints[bufnr] = breapoints[bufnr] or {}
        session:set_breakpoints(breapoints)
    end
end

return M
