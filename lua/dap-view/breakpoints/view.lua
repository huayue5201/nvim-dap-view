local state = require("dap-view.state")
local vendor = require("dap-view.breakpoints.vendor")
local extmarks = require("dap-view.breakpoints.util.extmarks")
local treesitter = require("dap-view.breakpoints.util.treesitter")
local setup = require("dap-view.setup")
local views = require("dap-view.views")
local util = require("dap-view.util")
local hl = require("dap-view.util.hl")

local M = {}

local api = vim.api

M.show = function()
    -- We have to check if the win is valid, since this function may be triggered by an event when the window is closed
    if util.is_buf_valid(state.bufnr) and util.is_win_valid(state.winnr) then
        local entries = vendor.get()

        local line = 0

        if views.cleanup_view(vim.tbl_isempty(entries), "No breakpoints") then
            return
        end

        for i in ipairs(state.breakpoint_paths_by_line) do
            state.breakpoint_paths_by_line[i] = nil
        end

        for i in ipairs(state.breakpoint_lines_by_line) do
            state.breakpoint_lines_by_line[i] = nil
        end

        for i in ipairs(state.breakpoint_entries_by_line) do
            state.breakpoint_entries_by_line[i] = nil
        end

        ---@type integer[][]
        local lengths = {}

        local num_parts = 0

        for _, entry in ipairs(entries) do
            local parts
            local path
            local lnum

            if entry.parts then
                -- Custom breakpoint: pre-rendered parts provided by the user
                parts = entry.parts
                path = entry.path
                lnum = entry.lnum
            else
                -- Native source breakpoint
                local buf_lines = api.nvim_buf_get_lines(entry.bufnr, entry.lnum - 1, entry.lnum, true)
                local text = table.concat(buf_lines, "\n")
                local filename = api.nvim_buf_get_name(entry.bufnr)
                local relative_path = vim.fn.fnamemodify(filename, ":.")

                parts = setup.config.render.breakpoints.format(text, tostring(entry.lnum), relative_path)
                path = relative_path
                lnum = entry.lnum
            end

            table.insert(state.breakpoint_paths_by_line, path)
            table.insert(state.breakpoint_lines_by_line, lnum)
            table.insert(state.breakpoint_entries_by_line, entry)

            for _, p in ipairs(parts) do
                assert(not p.separator or #p.separator == 1, "Separator length must not exceeed 1 character")
            end

            num_parts = #parts - 1

            lengths[#lengths + 1] = vim.iter(parts)
                :map(
                    ---@param part dapview.Content
                    function(part)
                        return #part.text
                    end
                )
                :totable()

            local content = ""
            for k, p in ipairs(parts) do
                content = content .. p.text
                if k ~= #parts then
                    content = content .. (p.separator or "|")
                end
            end

            util.set_lines(state.bufnr, line, line, false, { content })

            local hl_init = 0
            for _, p in ipairs(parts) do
                if p.hl then
                    local hl_end = hl_init + #p.text

                    if type(p.hl) == "string" then
                        ---@cast p {hl: string}
                        hl.hl_range(p.hl, { line, hl_init }, { line, hl_end })
                    else
                        treesitter.copy_highlights(entry.bufnr, entry.lnum - 1, line, hl_init)
                        extmarks.copy_extmarks(entry.bufnr, entry.lnum - 1, line, hl_init)
                    end

                    hl.hl_range("Separator", { line, hl_end }, { line, hl_end + 1 })

                    hl_init = hl_init + #p.text + 1
                end
            end

            line = line + 1
        end

        if setup.config.render.breakpoints.align then
            -- Alignment assumes every row has the same number of parts. Custom breakpoints
            -- may render fewer parts (e.g. instruction breakpoints), so only align when
            -- the shape is uniform.
            local uniform = true
            local first_len = lengths[1] and #lengths[1] or 0
            for _, l in ipairs(lengths) do
                if #l ~= first_len then
                    uniform = false
                    break
                end
            end

            if uniform then
                require("dap-view.util.align").align(num_parts, lengths)
            end
        end

        -- Clear previous content
        util.set_lines(state.bufnr, line, -1, true, {})
    end
end

return M
