-- RESTisch HTTP client module (async curl wrapper)
local M = {}

-- Build curl command from request options
function M.build_command(opts)
  local cmd = {
    "curl",
    "-s",                           -- Silent mode
    "-i",                           -- Include response headers
    "-w", "\n---RESTISCH_META---\n%{http_code}\n%{time_total}\n%{size_download}",
  }

  -- Add method
  table.insert(cmd, "-X")
  table.insert(cmd, opts.method or "GET")

  -- Add headers
  if opts.headers then
    for _, h in ipairs(opts.headers) do
      if h.key and h.key ~= "" then
        table.insert(cmd, "-H")
        table.insert(cmd, h.key .. ": " .. (h.value or ""))
      end
    end
  end

  -- Add body for methods that support it
  local body_methods = { POST = true, PUT = true, PATCH = true, DELETE = true }
  if body_methods[opts.method] and opts.body and #opts.body > 0 then
    table.insert(cmd, "-d")
    table.insert(cmd, opts.body)
  end

  -- Add URL
  table.insert(cmd, opts.url)

  return cmd
end

-- Parse curl response with headers
function M.parse_response(data)
  local output = table.concat(data, "\n")

  -- Split by our meta marker
  local meta_start = output:find("---RESTISCH_META---")
  if not meta_start then
    return { error = "Failed to parse response" }
  end

  local response_part = output:sub(1, meta_start - 1)
  local meta_part = output:sub(meta_start + 20)

  -- Parse meta info
  local meta_lines = vim.split(vim.trim(meta_part), "\n")
  local status = tonumber(meta_lines[1]) or 0
  local time_s = tonumber(meta_lines[2]) or 0
  local size = tonumber(meta_lines[3]) or 0

  -- Parse headers and body from response
  local header_end = response_part:find("\r?\n\r?\n")
  local headers_raw = ""
  local body = ""

  if header_end then
    headers_raw = response_part:sub(1, header_end - 1)
    body = vim.trim(response_part:sub(header_end + 2))
    -- Remove potential leading newlines from body
    body = body:gsub("^\r?\n", "")
  else
    body = response_part
  end

  -- Parse headers into table
  local headers = {}
  for line in headers_raw:gmatch("[^\r\n]+") do
    local key, value = line:match("^([^:]+):%s*(.+)$")
    if key and value then
      table.insert(headers, { key = key, value = value })
    end
  end

  return {
    status = status,
    status_text = M.get_status_text(status),
    headers = headers,
    headers_raw = headers_raw,
    body = body,
    time_ms = time_s * 1000,
    size = size,
  }
end

-- Get HTTP status text
function M.get_status_text(status)
  local texts = {
    [200] = "OK",
    [201] = "Created",
    [204] = "No Content",
    [301] = "Moved Permanently",
    [302] = "Found",
    [304] = "Not Modified",
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [409] = "Conflict",
    [422] = "Unprocessable Entity",
    [429] = "Too Many Requests",
    [500] = "Internal Server Error",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
  }
  return texts[status] or ""
end

-- Execute HTTP request asynchronously
function M.request(opts, callback)
  if not opts.url or opts.url == "" or opts.url == "https://" then
    callback({ error = "URL is required" })
    return
  end

  -- Auto-prepend https:// if no protocol specified
  if not opts.url:match("^https?://") then
    opts.url = "https://" .. opts.url
  end

  local cmd = M.build_command(opts)
  local stdout_data = {}
  local stderr_data = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          local err = table.concat(stderr_data, "\n")
          if err == "" then
            err = "curl exited with code " .. exit_code
          end
          callback({ error = err })
        else
          local response = M.parse_response(stdout_data)
          callback(response)
        end
      end)
    end,
  })
end

return M
