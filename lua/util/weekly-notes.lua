local M = {}

local DAY = 24 * 60 * 60
local NOTES_DIR = vim.fn.expand("~/Documents/notes")

local function week_start(ts)
  local wday = tonumber(os.date("%w", ts))
  return ts - wday * DAY
end

local function week_filepath(sunday_ts)
  local year = os.date("%Y", sunday_ts)
  local week = os.date("%U", sunday_ts)
  return string.format("%s/%s-W%s.md", NOTES_DIR, year, week)
end

local function build_scaffold(sunday_ts)
  local saturday_ts = sunday_ts + 6 * DAY
  local week_num = os.date("%U", sunday_ts)
  local range = os.date("%b %d", sunday_ts) .. " - " .. os.date("%b %d, %Y", saturday_ts)

  local lines = {
    "# Week " .. week_num .. " - " .. range,
    "",
    "## Week Tasks",
    "",
    "- [ ] ",
    "",
    "---",
    "",
  }

  for offset = 0, 6 do
    local ts = sunday_ts + offset * DAY
    local wday = tonumber(os.date("%w", ts))
    local weekday = os.date("%A", ts)
    local date = os.date("%Y-%m-%d", ts)

    table.insert(lines, string.format("## %-9s %s", weekday, date))
    table.insert(lines, "")
    table.insert(lines, "### Tasks")
    table.insert(lines, "")
    table.insert(lines, "- [ ] ")
    table.insert(lines, "")

    if wday >= 1 and wday <= 5 then
      table.insert(lines, "### Work tasks")
      table.insert(lines, "")
      table.insert(lines, "- [ ] ")
      table.insert(lines, "- [ ] End workday")
      table.insert(lines, "      - document in Jira")
      table.insert(lines, "      - Log hours BCS")
      table.insert(lines, "      - Prepare next day's todo's")
      table.insert(lines, "")
    end

    table.insert(lines, "### Notes")
    table.insert(lines, "")
    table.insert(lines, "")
  end

  return lines
end

local function create_if_missing(filepath, sunday_ts)
  vim.fn.mkdir(NOTES_DIR, "p")
  if vim.fn.filereadable(filepath) == 1 then return end
  local f = io.open(filepath, "w")
  if not f then return end
  f:write(table.concat(build_scaffold(sunday_ts), "\n"))
  f:close()
end

local function jump_to_weekday(weekday_name)
  local lnum = vim.fn.search("^## " .. weekday_name .. "\\>", "nw")
  if lnum > 0 then
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.cmd("normal! zMzv")
  end
end

function M.open_offset(weeks)
  weeks = weeks or 0
  local sunday = week_start(os.time() + weeks * 7 * DAY)
  local filepath = week_filepath(sunday)
  create_if_missing(filepath, sunday)
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  jump_to_weekday(os.date("%A"))
end

function M.open_current()
  M.open_offset(0)
end

function M.foldexpr(lnum)
  local line = vim.fn.getline(lnum)
  if line:match("^## ") then return ">1" end
  return "="
end

function M.foldtext()
  local line = vim.fn.getline(vim.v.foldstart)
  local count = vim.v.foldend - vim.v.foldstart + 1
  return line .. "  ... " .. count .. " lines"
end

function M.setup_folds()
  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.require'util.weekly-notes'.foldexpr(v:lnum)"
  vim.opt_local.foldtext = "v:lua.require'util.weekly-notes'.foldtext()"
  vim.opt_local.foldlevel = 0
  vim.opt_local.fillchars:append({ fold = " " })
end

return M
