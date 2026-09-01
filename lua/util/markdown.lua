-- Small markdown editing helpers, wired to <leader>m* for markdown buffers in
-- lua/config/keymaps.lua. No plugin — just buffer text manipulation.
local M = {}

-- Toggle `- [ ]` <-> `- [x]` on the given 1-indexed line. Adds `[ ]` to a bare
-- `- ` bullet; leaves non-list lines alone. Returns true if it changed anything.
local function toggle_line(lnum)
    local line = vim.fn.getline(lnum)
    local new
    if line:match("^(%s*[-*+] )%[[ ]%]") then
        new = line:gsub("(%s*[-*+] )%[[ ]%]", "%1[x]", 1)
    elseif line:match("^(%s*[-*+] )%[[xX]%]") then
        new = line:gsub("(%s*[-*+] )%[[xX]%]", "%1[ ]", 1)
    elseif line:match("^(%s*[-*+] )") then
        new = line:gsub("^(%s*[-*+] )", "%1[ ] ", 1)
    else
        return false
    end
    vim.fn.setline(lnum, new)
    return true
end

-- Normal mode: current line. Visual mode: every line in the selection.
function M.toggle_checkbox()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local s = vim.fn.line("v")
        local e = vim.fn.line(".")
        if s > e then
            s, e = e, s
        end
        for l = s, e do
            toggle_line(l)
        end
        vim.api.nvim_input("<Esc>")
    else
        toggle_line(vim.fn.line("."))
    end
end

-- Jump to a heading via vim.ui.select. Indented by heading depth.
function M.toc()
    local items = {}
    for lnum, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        local hashes, title = text:match("^(#+)%s+(.+)$")
        if hashes and not text:match("^#+%s*$") then
            table.insert(items, {
                lnum = lnum,
                label = ("  "):rep(#hashes - 1) .. title,
            })
        end
    end
    if #items == 0 then
        vim.notify("No headings", vim.log.levels.INFO)
        return
    end
    vim.ui.select(items, {
        prompt = "TOC",
        format_item = function(it)
            return it.label
        end,
    }, function(choice)
        if choice then
            vim.api.nvim_win_set_cursor(0, { choice.lnum, 0 })
            vim.cmd("normal! zz")
        end
    end)
end

-- Reflow markdown through prettier (conform): pads/aligns every pipe-table,
-- normalises list markers, rewraps. prettier has no range mode, so this is a
-- whole-buffer format — same as <leader>lf, kept under <leader>mt as the
-- table-fixing muscle-memory key.
function M.format_table()
    require("conform").format({ bufnr = 0, lsp_fallback = true })
end

-- ── Link following ────────────────────────────────────────────────────────
-- Resolve the link under the cursor and open it. Handles:
--   [text](path/to/file.md#anchor)  · relative to the current file's dir
--   [text](https://…)               · opened in the browser
--   [[wikilink]] / [[wikilink|alt]] · <dir>/wikilink.md, created if missing
-- Falls back to the default <CR> / gf behaviour when there's no link here.
local function link_target()
    local line = vim.fn.getline(".")
    local col = vim.fn.col(".") -- 1-indexed, cursor byte

    -- [[wiki]] first (its inner text can contain no brackets)
    for s, body, e in line:gmatch("()%[%[([^%]]+)%]%]()") do
        if col >= s and col < e then
            return { kind = "wiki", value = body:match("^([^|]+)") }
        end
    end
    -- [text](dest) — accept a cursor anywhere in the whole [..](..)
    for s, dest, e in line:gmatch("()%]%(([^)]+)%)()") do
        local open = line:sub(1, s):match(".*()%[") -- last '[' before the ']('
        if open and col >= open and col < e then
            return { kind = "md", value = vim.trim(dest) }
        end
    end
end

function M.follow_link()
    local t = link_target()
    if not t then
        -- no link: behave like a normal <CR>
        vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
        return
    end

    if t.kind == "md" and t.value:match("^%a[%w+.-]*://") then
        vim.ui.open(t.value)
        return
    end

    local path
    if t.kind == "wiki" then
        path = t.value
        if not path:match("%.%w+$") then
            path = path .. ".md"
        end
    else
        path = (t.value:gsub("#.*$", "")) -- strip anchor
    end
    if path == "" then
        return
    end -- pure #anchor — nothing to open (marksman handles those)

    if not path:match("^[/~]") then
        path = vim.fs.normalize(vim.fn.expand("%:p:h") .. "/" .. path)
    else
        path = vim.fs.normalize(path)
    end
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.cmd.edit(vim.fn.fnameescape(path))
end

-- ── Paste clipboard URL as a markdown link over the selection ──────────────
-- Visual mode: replace the selection with [selection](<clipboard>). If the
-- clipboard isn't a URL, wrap it as a link anyway (handy for relative paths).
function M.paste_url_link()
    local url = vim.trim(vim.fn.getreg("+"))
    if url == "" then
        url = vim.trim(vim.fn.getreg('"'))
    end
    -- capture the selection while still in visual mode, then leave it
    local a = vim.fn.getpos("v")
    local b = vim.fn.getpos(".")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    local sr, sc, er, ec = a[2], a[3], b[2], b[3]
    if sr > er or (sr == er and sc > ec) then
        sr, sc, er, ec = er, ec, sr, sc
    end
    local text = table.concat(vim.api.nvim_buf_get_text(0, sr - 1, sc - 1, er - 1, ec, {}), " ")
    vim.api.nvim_buf_set_text(0, sr - 1, sc - 1, er - 1, ec, { ("[%s](%s)"):format(text, url) })
end

-- ── Heading navigation ────────────────────────────────────────────────────
function M.next_heading()
    vim.fn.search("^#\\+\\s", "W")
end
function M.prev_heading()
    vim.fn.search("^#\\+\\s", "bW")
end

return M
