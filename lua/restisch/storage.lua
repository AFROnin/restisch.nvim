-- RESTisch storage module for saving/loading requests
local M = {}

-- Get the storage directory path
function M.get_storage_dir()
  local dir = vim.fn.stdpath("data") .. "/restisch/requests"
  return dir
end

-- Ensure storage directory exists
function M.ensure_dir()
  local dir = M.get_storage_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

-- Save a request to disk
function M.save(name, request_data)
  local dir = M.ensure_dir()
  local filename = name:gsub("[^%w%-_]", "-") .. ".json"
  local path = dir .. "/" .. filename

  local data = {
    name = name,
    method = request_data.method,
    url = request_data.url,
    headers = request_data.headers,
    body = request_data.body,
    created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  local json = vim.json.encode(data)
  local file = io.open(path, "w")
  if file then
    file:write(json)
    file:close()
    return true, path
  end
  return false, "Failed to write file"
end

-- Load a request from disk
function M.load(name)
  local dir = M.get_storage_dir()
  local filename = name:gsub("[^%w%-_]", "-") .. ".json"
  local path = dir .. "/" .. filename

  local file = io.open(path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok then
      return data
    end
  end
  return nil
end

-- List all saved requests
function M.list()
  local dir = M.get_storage_dir()
  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end

  local files = vim.fn.glob(dir .. "/*.json", false, true)
  local requests = {}

  for _, path in ipairs(files) do
    local file = io.open(path, "r")
    if file then
      local content = file:read("*a")
      file:close()
      local ok, data = pcall(vim.json.decode, content)
      if ok then
        table.insert(requests, {
          name = data.name or vim.fn.fnamemodify(path, ":t:r"),
          method = data.method or "GET",
          url = data.url or "",
          path = path,
        })
      end
    end
  end

  -- Sort by name
  table.sort(requests, function(a, b)
    return a.name < b.name
  end)

  return requests
end

-- Delete a saved request
function M.delete(name)
  local dir = M.get_storage_dir()
  local filename = name:gsub("[^%w%-_]", "-") .. ".json"
  local path = dir .. "/" .. filename

  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
    return true
  end
  return false
end

return M
