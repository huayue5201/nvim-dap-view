local setup = require("dap-view.setup")

local M = {}

local NVIM_DAP_NAMESPACE = "dap_breakpoints"

---@class SignDict
---@field group string
---@field id integer
---@field lnum integer
---@field name string
---@field priority integer

---@class PlacedSigns
---@field bufnr integer
---@field signs SignDict

---@param bufnr? integer
---@return PlacedSigns
local function get_breakpoint_signs(bufnr)
    if bufnr then
        return vim.fn.sign_getplaced(bufnr, { group = NVIM_DAP_NAMESPACE })
    end

    local bufs_with_signs = vim.fn.sign_getplaced()

    local result = {}

    for _, buf_signs in ipairs(bufs_with_signs) do
        buf_signs = vim.fn.sign_getplaced(buf_signs.bufnr, { group = NVIM_DAP_NAMESPACE })[1]

        if #buf_signs.signs > 0 then
            table.insert(result, buf_signs)
        end
    end

    return result
end

--- Gather breakpoints from nvim-dap signs and, optionally, from a user-provided
--- `render.breakpoints.get_extra` hook (custom breakpoints).
---
---@param bufnr? integer
---@return (dapview.ExtraBreakpointEntry | {bufnr: integer, lnum: integer})[]
function M.get(bufnr)
    local entries = {}

    -- 1) nvim-dap native source breakpoints (sign group: dap_breakpoints)
    local signs = get_breakpoint_signs(bufnr)

    for _, buf_signs in ipairs(signs) do
        local buf = buf_signs.bufnr

        for _, breakpoint_sign in ipairs(buf_signs.signs) do
            table.insert(entries, {
                bufnr = buf,
                lnum = breakpoint_sign.lnum,
            })
        end
    end

    -- 2) Custom breakpoints provided by the user
    local get_extra = setup.config.render.breakpoints.get_extra
    if get_extra then
        local ok, extra = pcall(get_extra)
        if ok and type(extra) == "table" then
            for _, entry in ipairs(extra) do
                if not bufnr or entry.bufnr == bufnr then
                    table.insert(entries, entry)
                end
            end
        end
    end

    return entries
end

return M
