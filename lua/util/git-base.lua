-- Which branch did the current branch fork from?
--
-- Naive answer ("main, or master, or develop, first one that exists") is wrong
-- in repos that develop off a long-lived integration branch: in the techweb2.0
-- backend, main..HEAD is 728 commits / 908 files while develop..HEAD is 79
-- commits / 153 files. Instead score every plausible base by how many of HEAD's
-- commits it is missing and take the smallest non-zero -- the nearest ancestor.
local M = {}

local CANDIDATES = {
    "main", "master", "develop", "dev",
    "origin/main", "origin/master", "origin/develop", "origin/dev",
}

local function repo_dir()
    local dir = vim.fn.expand("%:p:h")
    if dir == "" or vim.fn.isdirectory(dir) == 0 then return vim.fn.getcwd() end
    return dir
end

local function git(args, cwd)
    local res = vim.system({ "git", unpack(args) }, { cwd = cwd or repo_dir(), text = true }):wait()
    if res.code ~= 0 then return nil end
    return vim.trim(res.stdout)
end

--- @return string|nil base branch name, @return number|nil commits HEAD is ahead
function M.nearest(cwd)
    cwd = cwd or repo_dir()
    local head = git({ "symbolic-ref", "--quiet", "--short", "HEAD" }, cwd)

    local candidates = {}
    -- origin/HEAD is the repo's declared default branch, but it is only set by
    -- `git clone` / `git remote set-head`, so it is often simply absent.
    local ref = git({ "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD" }, cwd)
    if ref then table.insert(candidates, (ref:gsub("^refs/remotes/", ""))) end
    vim.list_extend(candidates, CANDIDATES)

    local best, best_ahead
    local seen = {}
    for _, name in ipairs(candidates) do
        if not seen[name] and name ~= head then
            seen[name] = true
            if git({ "rev-parse", "--verify", "--quiet", name }, cwd) then
                local ahead = tonumber(git({ "rev-list", "--count", name .. "..HEAD" }, cwd) or "")
                -- ahead == 0 means HEAD adds nothing over that branch (you are
                -- sitting on it, or it already contains your work) -- useless as
                -- a diff base, so skip rather than return an empty diff.
                if ahead and ahead > 0 and (not best_ahead or ahead < best_ahead) then
                    best, best_ahead = name, ahead
                end
            end
        end
    end
    return best, best_ahead
end

return M
