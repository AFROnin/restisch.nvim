-- RESTisch response panel module
local Popup = require("nui.popup")

local M = {}

-- Current state
M.state = {
  popup = nil,
  response = nil,
  show_headers = false,
}

-- Get highlight group for status code
local function get_status_hl(status)
  if not status or status == 0 then
    return "Comment"
  elseif status >= 200 and status < 300 then
    return "RestischSuccess"
  elseif status >= 300 and status < 400 then
    return "RestischRedirect"
  else
    return "RestischError"
  end
end

-- Check if response content type is JSON
local function is_json_content(response)
  if not response or not response.headers then
    return false
  end
  for _, h in ipairs(response.headers) do
    if h.key:lower() == "content-type" then
      return h.value:lower():find("application/json") ~= nil
        or h.value:lower():find("application/.*%+json") ~= nil
    end
  end
  return false
end

-- Apply JSON syntax highlights to body lines
local function apply_json_highlights(bufnr, body_start_line, body_lines)
  for i, line in ipairs(body_lines) do
    local buf_line = body_start_line + i - 1

    -- Match JSON keys: "key":
    local key_start, key_end = line:find('"[^"]-"%s*:')
    if key_start then
      pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonKey", buf_line, key_start - 1, key_end - 1)

      -- Match value after the colon
      local after_colon = line:sub(key_end + 1)
      local val_offset = key_end

      -- String value
      local vs, ve = after_colon:find('%s*"[^"]*"')
      if vs then
        pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonString", buf_line, val_offset + vs - 1, val_offset + ve)
      else
        -- Number value
        vs, ve = after_colon:find("%s*%-?%d+%.?%d*[eE]?[+-]?%d*")
        if vs and ve > vs then
          pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonNumber", buf_line, val_offset + vs - 1, val_offset + ve)
        else
          -- Boolean / null
          vs, ve = after_colon:find("%s*(true)")
          if not vs then vs, ve = after_colon:find("%s*(false)") end
          if not vs then vs, ve = after_colon:find("%s*(null)") end
          if vs then
            pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonBoolean", buf_line, val_offset + vs - 1, val_offset + ve)
          end
        end
      end
    else
      -- Array string values (not keys)
      for sv_start, sv_end in line:gmatch('()"[^"]*"()') do
        if type(sv_start) == "number" then
          pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonString", buf_line, sv_start - 1, sv_end - 1)
        end
      end
      -- Standalone numbers in arrays
      for ns, ne in line:gmatch("()%-?%d+%.?%d*[eE]?[+-]?%d*()") do
        if type(ns) == "number" then
          local before = line:sub(1, ns - 1)
          -- Only highlight if it looks like a standalone value (preceded by space/comma/bracket)
          if before:match("[%s,%[:]%s*$") or before == "" then
            pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonNumber", buf_line, ns - 1, ne - 1)
          end
        end
      end
      -- Standalone booleans/null in arrays
      for _, keyword in ipairs({ "true", "false", "null" }) do
        local ks, ke = line:find(keyword, 1, true)
        if ks then
          pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonBoolean", buf_line, ks - 1, ke)
        end
      end
    end

    -- Braces/brackets
    for bs in line:gmatch("()[%{%}%[%]]") do
      if type(bs) == "number" then
        pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "RestischJsonBrace", buf_line, bs - 1, bs)
      end
    end
  end
end

-- Spinner frames for loading animation
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_timer = nil
local spinner_index = 1

-- Pretty print JSON
function M.pretty_json(json_str)
  local ok, parsed = pcall(vim.json.decode, json_str)
  if not ok then
    return json_str
  end

  local function serialize(val, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local t = type(val)

    if t == "nil" then
      return "null"
    elseif t == "boolean" then
      return tostring(val)
    elseif t == "number" then
      return tostring(val)
    elseif t == "string" then
      return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif t == "table" then
      -- Check if array
      local is_array = vim.islist(val)

      if is_array then
        if #val == 0 then
          return "[]"
        end
        local items = {}
        for _, v in ipairs(val) do
          table.insert(items, spaces .. "  " .. serialize(v, indent + 1))
        end
        return "[\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "]"
      else
        local keys = vim.tbl_keys(val)
        if #keys == 0 then
          return "{}"
        end
        table.sort(keys, function(a, b)
          return tostring(a) < tostring(b)
        end)
        local items = {}
        for _, k in ipairs(keys) do
          local key_str = '"' .. tostring(k) .. '"'
          table.insert(items, spaces .. "  " .. key_str .. ": " .. serialize(val[k], indent + 1))
        end
        return "{\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "}"
      end
    end
    return tostring(val)
  end

  return serialize(parsed, 0)
end

-- Create the response panel
function M.create()
  local config = require("restisch.config").get()

  local popup = Popup({
    border = {
      style = config.border,
      text = {
        top = " Response ",
        top_align = "center",
      },
      padding = { top = 0, bottom = 0, left = 1, right = 1 },
    },
    buf_options = {
      modifiable = false,
      filetype = "json",
    },
    win_options = {
      cursorline = false,
      wrap = true,
      scrolloff = 2,
      winhighlight = "Normal:Normal,FloatBorder:RestischBorder",
    },
  })

  M.state.popup = popup

  return popup
end

-- Render the response panel content
function M.render()
  local popup = M.state.popup
  if not popup or not popup.bufnr then
    return
  end

  vim.bo[popup.bufnr].modifiable = true

  local lines = {}
  local highlights = {}

  if not M.state.response then
    -- No response yet
    table.insert(lines, "")
    table.insert(lines, " No response yet.")
    table.insert(lines, "")
    table.insert(lines, " Press <CR> in the request panel to send.")
    table.insert(highlights, {
      line = 1,
      col_start = 0,
      col_end = -1,
      hl = "Comment",
    })
    table.insert(highlights, {
      line = 3,
      col_start = 0,
      col_end = -1,
      hl = "Comment",
    })
  elseif M.state.response.error then
    -- Error response
    table.insert(lines, "")
    table.insert(lines, " Error:")
    table.insert(lines, "")
    for _, err_line in ipairs(vim.split(M.state.response.error, "\n")) do
      table.insert(lines, " " .. err_line)
    end
    table.insert(highlights, {
      line = 1,
      col_start = 0,
      col_end = -1,
      hl = "RestischError",
    })
  else
    -- Success response
    local resp = M.state.response

    -- Status line
    local status_text = string.format(" %d %s", resp.status, resp.status_text or "")
    local time_text = string.format("  %.0fms", resp.time_ms or 0)
    local size_text = resp.size and resp.size > 0 and string.format("  %s", M.format_size(resp.size)) or ""

    table.insert(lines, status_text .. time_text .. size_text)
    table.insert(highlights, {
      line = 0,
      col_start = 0,
      col_end = #status_text,
      hl = get_status_hl(resp.status),
    })
    table.insert(highlights, {
      line = 0,
      col_start = #status_text,
      col_end = #status_text + #time_text,
      hl = "RestischTime",
    })
    table.insert(highlights, {
      line = 0,
      col_start = #status_text + #time_text,
      col_end = -1,
      hl = "Comment",
    })

    -- Headers toggle hint
    table.insert(lines, "")
    local headers_hint = M.state.show_headers and " [h] Hide headers" or " [h] Show headers"
    table.insert(lines, headers_hint)
    table.insert(highlights, {
      line = 2,
      col_start = 0,
      col_end = -1,
      hl = "Comment",
    })

    -- Headers (if showing)
    if M.state.show_headers and resp.headers and #resp.headers > 0 then
      table.insert(lines, "")
      table.insert(lines, " ─── Headers ───")
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 0,
        col_end = -1,
        hl = "RestischLabel",
      })
      for _, h in ipairs(resp.headers) do
        local header_line = string.format("   %s: %s", h.key, h.value)
        table.insert(lines, header_line)
      end
    end

    -- Body
    table.insert(lines, "")
    table.insert(lines, " ─── Body ───")
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
      hl = "RestischLabel",
    })
    table.insert(lines, "")

    local json_body_lines = nil
    local json_body_start = nil

    if resp.body and resp.body ~= "" then
      local content_is_json = is_json_content(resp)
      -- If content-type indicates JSON, or if no content-type header, try to format as JSON
      if content_is_json or not resp.headers or #resp.headers == 0 then
        local formatted_body = M.pretty_json(resp.body)
        -- Check if pretty_json actually parsed it (returns different string if it parsed)
        local parse_ok = pcall(vim.json.decode, resp.body)
        if parse_ok then
          json_body_start = #lines
          json_body_lines = {}
          for _, body_line in ipairs(vim.split(formatted_body, "\n")) do
            table.insert(lines, " " .. body_line)
            table.insert(json_body_lines, " " .. body_line)
          end
        else
          -- Not valid JSON, show as plain text
          for _, body_line in ipairs(vim.split(resp.body, "\n")) do
            table.insert(lines, " " .. body_line)
          end
        end
      else
        -- Non-JSON content type, show as plain text
        for _, body_line in ipairs(vim.split(resp.body, "\n")) do
          table.insert(lines, " " .. body_line)
        end
      end
    else
      table.insert(lines, " (empty body)")
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 0,
        col_end = -1,
        hl = "Comment",
      })
    end
  end

  -- Set lines
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    pcall(vim.api.nvim_buf_add_highlight, popup.bufnr, -1, hl.hl, hl.line, hl.col_start, hl.col_end)
  end

  -- Apply JSON syntax highlighting if we have JSON body
  if json_body_lines and json_body_start then
    apply_json_highlights(popup.bufnr, json_body_start, json_body_lines)
  end

  vim.bo[popup.bufnr].modifiable = false
end

-- Format file size
function M.format_size(bytes)
  if bytes < 1024 then
    return bytes .. " B"
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  else
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
end

-- Set response data
function M.set_response(response)
  M.stop_spinner()
  M.state.response = response
  M.render()
end

-- Stop the loading spinner
function M.stop_spinner()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
end

-- Show loading state with animated spinner
function M.show_loading()
  local popup = M.state.popup
  if not popup or not popup.bufnr then
    return
  end

  M.stop_spinner()
  spinner_index = 1

  local function update_spinner()
    if not popup.bufnr or not vim.api.nvim_buf_is_valid(popup.bufnr) then
      M.stop_spinner()
      return
    end
    local frame = spinner_frames[spinner_index]
    vim.bo[popup.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, {
      "",
      " " .. frame .. " Sending request...",
      "",
    })
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "RestischLabel", 1, 0, -1)
    vim.bo[popup.bufnr].modifiable = false
    spinner_index = spinner_index % #spinner_frames + 1
  end

  update_spinner()
  spinner_timer = vim.uv.new_timer()
  spinner_timer:start(80, 80, vim.schedule_wrap(update_spinner))
end

-- Setup keymaps for the response panel
function M.setup_keymaps()
  local popup = M.state.popup
  if not popup then
    return
  end

  local opts = { noremap = true, nowait = true }

  -- Toggle headers
  popup:map("n", "h", function()
    M.state.show_headers = not M.state.show_headers
    M.render()
  end, opts)

  -- Copy body to clipboard
  popup:map("n", "y", function()
    if M.state.response and M.state.response.body then
      vim.fn.setreg("+", M.state.response.body)
      vim.notify("Response body copied to clipboard", vim.log.levels.INFO)
    end
  end, opts)
end

-- Clear response
function M.clear()
  M.stop_spinner()
  M.state.response = nil
  M.state.show_headers = false
  M.render()
end

return M
