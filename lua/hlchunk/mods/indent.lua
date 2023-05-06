local BaseMod = require("hlchunk.base_mod")

local utils = require("hlchunk.utils.utils")
local Array = require("hlchunk.utils.array")
local api = vim.api
local fn = vim.fn

local whitespaceStyle = fn.synIDattr(fn.synIDtrans(fn.hlID("Whitespace")), "fg", "gui")
local exclude_ft = {
    aerial = true,
    dashboard = true,
    help = true,
    lspinfo = true,
    lspsagafinder = true,
    packer = true,
    checkhealth = true,
    man = true,
    mason = true,
    NvimTree = true,
    ["neo-tree"] = true,
    plugin = true,
    lazy = true,
    TelescopePrompt = true,
    [""] = true, -- because TelescopePrompt will set a empty ft, so add this.
    notify = true,
}

---@class IndentMod: BaseMod
---@field cached_lines table<number, number>
local indent_mod = BaseMod:new({
    name = "indent",
    cached_lines = {},
    options = {
        enable = true,
        use_treesitter = false,
        chars = {
            "│",
        },
        style = {
            whitespaceStyle,
        },
        exclude_filetype = exclude_ft,
    },
})

function indent_mod:render_line(index, indent)
    local row_opts = {
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = 2,
    }
    local render_char_num = math.floor(indent / vim.o.shiftwidth)
    local win_info = fn.winsaveview()
    local text = ""
    for _ = 1, render_char_num do
        text = text .. "|" .. (" "):rep(vim.o.shiftwidth - 1)
    end
    text = text:sub(win_info.leftcol + 1)

    local count = 0
    for i = 1, #text do
        local c = text:at(i)
        if not c:match("%s") then
            count = count + 1
            local Indent_chars_num = Array:from(self.options.chars):size()
            local Indent_style_num = Array:from(self.options.style):size()
            local char = self.options.chars[(count - 1) % Indent_chars_num + 1]
            local style = "HLIndent" .. tostring((count - 1) % Indent_style_num + 1)
            row_opts.virt_text = { { char, style } }
            row_opts.virt_text_win_col = i - 1
            api.nvim_buf_set_extmark(0, self.ns_id, index - 1, 0, row_opts)
        end
    end
end

function indent_mod:render(scrolled)
    scrolled = scrolled or false

    if (not self.options.enable) or self.options.exclude_filetype[vim.bo.filetype] then
        return
    end

    if not scrolled then
        self:clear(fn.line("w0"), fn.line("w$"))
    end
    self.ns_id = api.nvim_create_namespace("hl_indent")

    local rows_indent = utils.get_rows_indent(nil, nil, {
        use_treesitter = self.options.use_treesitter,
        virt_indent = true,
    })
    if not rows_indent then
        return
    end

    for index, _ in pairs(rows_indent) do
        if not (scrolled and self.cached_lines[index] and self.cached_lines[index] > 0) then
            self:render_line(index, rows_indent[index])
            self.cached_lines[index] = rows_indent[index]
        end
    end
end

function indent_mod:enable_mod_autocmd()
    api.nvim_create_augroup(self.augroup_name, { clear = true })

    api.nvim_create_autocmd({ "WinScrolled" }, {
        group = "hl_indent_augroup",
        -- TODO: how to get the window attact with current buffer?
        pattern = "*",
        callback = function()
            local cur_win_info = fn.winsaveview()
            local old_win_info = indent_mod.old_win_info

            if cur_win_info.lnum ~= old_win_info.lnum then
                indent_mod:render(true)
            elseif cur_win_info.leftcol ~= old_win_info.leftcol then
                indent_mod:render(false)
            end
            indent_mod.old_win_info = cur_win_info
        end,
    })
    api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter" }, {
        group = "hl_indent_augroup",
        pattern = "*",
        callback = function()
            indent_mod.cached_lines = {}
            indent_mod:render()
        end,
    })
    api.nvim_create_autocmd({ "OptionSet" }, {
        group = "hl_indent_augroup",
        pattern = "list,listchars,shiftwidth,tabstop,expandtab",
        callback = function()
            indent_mod:render()
        end,
    })
end

function indent_mod:disable()
    indent_mod.cached_lines = {}
    BaseMod.disable(self)
end

return indent_mod
