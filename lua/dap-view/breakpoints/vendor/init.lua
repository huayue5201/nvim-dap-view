-- nvim-dap-view/lua/dap-view/breakpoints/vendor/init.lua
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

---@param bufnr? integer
---@return table<integer, { lnum: integer }[]>
function M.get(bufnr)
    local signs = get_breakpoint_signs(bufnr)

    if #signs == 0 then
        return {}
    end

    local result = {}

    for _, buf_breakpoint_signs in pairs(signs) do
        local breakpoints = {}
        local buf = buf_breakpoint_signs.bufnr

        result[buf] = breakpoints

        for _, breakpoint_sign in pairs(buf_breakpoint_signs.signs) do
            table.insert(breakpoints, {
                lnum = breakpoint_sign.lnum,
            })
        end
    end

    -- 合并自定义断点（dap-extensions）
    local ok, registry = pcall(require, "dap-config.dap-extensions.registry")
    if ok and registry and registry.bps then
        for _, bp in pairs(registry.bps) do
            if bp.config and bp.config.bufnr and bp.config.line and bp.enabled ~= false then
                local bp_bufnr = bp.config.bufnr -- 重命名，避免与外层 bufnr 冲突
                result[bp_bufnr] = result[bp_bufnr] or {}
                table.insert(result[bp_bufnr], { lnum = bp.config.line })
            end
        end
    end

    return result
end

return M
