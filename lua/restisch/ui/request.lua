-- RESTisch request panel module
local Popup = require("nui.popup")
local Menu = require("nui.menu")
local Input = require("nui.input")
local M = {}

-- HTTP methods
M.methods = { "GET", "POST", "PUT", "PATCH", "DELETE" }

-- Current state
M.state = {
  method = "GET",
  url = "",
  headers = {},
  body = "",
  popup = nil,
  on_send = nil,
}

-- Common HTTP headers for autocomplete
local common_headers = {
  "Accept",
  "Accept-Charset",
  "Accept-Encoding",
  "Accept-Language",
  "Authorization",
  "Cache-Control",
  "Content-Disposition",
  "Content-Encoding",
  "Content-Language",
  "Content-Length",
  "Content-Type",
  "Cookie",
  "Date",
  "ETag",
  "Expect",
  "Expires",
  "From",
  "Host",
  "If-Match",
  "If-Modified-Since",
  "If-None-Match",
  "If-Range",
  "If-Unmodified-Since",
  "Last-Modified",
  "Location",
  "Max-Forwards",
  "Origin",
  "Pragma",
  "Proxy-Authorization",
  "Range",
  "Referer",
  "Retry-After",
  "Server",
  "Set-Cookie",
  "TE",
  "Trailer",
  "Transfer-Encoding",
  "Upgrade",
  "User-Agent",
  "Vary",
  "Via",
  "Warning",
  "WWW-Authenticate",
  "X-Api-Key",
  "X-Forwarded-For",
  "X-Forwarded-Host",
  "X-Forwarded-Proto",
  "X-Request-ID",
  "X-Requested-With",
}

-- Create the request panel
function M.create(on_send)
  local config = require("restisch.config").get()

  M.state.on_send = on_send
  M.state.headers = vim.deepcopy(config.default_headers or {})

  local popup = Popup({
    border = {
      style = config.border,
      text = {
        top = " Request ",
        top_align = "center",
      },
      padding = { top = 0, bottom = 0, left = 1, right = 1 },
    },
    buf_options = {
      modifiable = false,
    },
    win_options = {
      cursorline = true,
      winhighlight = "Normal:Normal,FloatBorder:RestischBorder",
      scrolloff = 0,
      wrap = false,
    },
  })

  M.state.popup = popup

  return popup
end

-- Render the request panel content
function M.render()
  local popup = M.state.popup
  if not popup or not popup.bufnr then
    return
  end

  vim.bo[popup.bufnr].modifiable = true

  local lines = {}
  local highlights = {}
  local methods_with_body = { POST = true, PUT = true, PATCH = true, DELETE = true }

  -- Help text in winbar (pinned, never scrolls, right-aligned)
  if popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
    local help = "a:header  dd:del  c:curl  C-s:save  C-o:load"
    if methods_with_body[M.state.method] then
      help = help .. "  b:body"
    end
    help = help .. "  <CR>:send "
    local winbar = "%#RestischWinbarFill#%=%#RestischWinbar#" .. help
    vim.wo[popup.winid].winbar = winbar
  end

  -- Separator below winbar (full width, in panel border color)
  local sep_width = 80
  if popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
    sep_width = vim.api.nvim_win_get_width(popup.winid)
  end
  table.insert(lines, string.rep("─", sep_width))
  table.insert(highlights, {
    line = #lines - 1,
    col_start = 0,
    col_end = -1,
    hl = "RestischBorder",
  })

  -- Method and URL line
  local method_line = string.format(" [%s] ", M.state.method)
  local url_display = M.state.url ~= "" and M.state.url or "(press 'u' to set URL)"
  table.insert(lines, method_line .. url_display)
  local method_hl = "RestischMethod" .. M.state.method
  table.insert(highlights, {
    line = #lines - 1,
    col_start = 0,
    col_end = #method_line,
    hl = method_hl,
  })
  table.insert(highlights, {
    line = #lines - 1,
    col_start = #method_line,
    col_end = #method_line + #url_display,
    hl = "RestischUrl",
  })

  -- Separator
  table.insert(lines, "")
  table.insert(lines, " ─── Headers ───")
  table.insert(highlights, {
    line = #lines - 1,
    col_start = 0,
    col_end = -1,
    hl = "RestischLabel",
  })

  -- Track where headers start (1-indexed line number for cursor mapping)
  M.state.header_start_line = #lines + 1

  -- Headers
  if #M.state.headers == 0 then
    table.insert(lines, "   (no headers - press 'a' to add)")
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
      hl = "Comment",
    })
  else
    for _, h in ipairs(M.state.headers) do
      local header_line = string.format("   %s: %s", h.key, h.value)
      table.insert(lines, header_line)
      local key_end = 3 + #h.key
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 3,
        col_end = key_end,
        hl = "RestischHeaderKey",
      })
      table.insert(highlights, {
        line = #lines - 1,
        col_start = key_end + 2,
        col_end = -1,
        hl = "RestischHeaderValue",
      })
    end
  end

  -- Body section (only for methods that can have a payload)
  if methods_with_body[M.state.method] then
    table.insert(lines, "")
    table.insert(lines, " ─── Body ───")
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 0,
      col_end = -1,
      hl = "RestischLabel",
    })

    -- Body preview
    if M.state.body == "" then
      table.insert(lines, "   (empty - press 'b' to edit)")
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 0,
        col_end = -1,
        hl = "Comment",
      })
    else
      -- Show all body lines (no limit for auto-sizing)
      local body_lines = vim.split(M.state.body, "\n")
      for _, bline in ipairs(body_lines) do
        table.insert(lines, "   " .. bline)
      end
    end
  end

  -- Set lines
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, hl.hl, hl.line, hl.col_start, hl.col_end)
  end

  vim.bo[popup.bufnr].modifiable = false

  -- Notify main to resize if needed
  M.last_content_lines = #lines
end

-- Get the number of content lines for auto-sizing
function M.get_content_height()
  return M.last_content_lines or 10
end

-- Setup keymaps for the request panel
function M.setup_keymaps()
  local popup = M.state.popup
  if not popup then
    return
  end

  local opts = { noremap = true, nowait = true }

  -- Method selector
  popup:map("n", "m", function()
    M.show_method_menu()
  end, opts)

  -- URL input
  popup:map("n", "u", function()
    M.show_url_input()
  end, opts)

  -- Add header
  popup:map("n", "a", function()
    M.show_add_header()
  end, opts)

  -- Delete header (when cursor is on a header line)
  popup:map("n", "dd", function()
    M.delete_header_at_cursor()
  end, opts)

  -- Edit body
  popup:map("n", "b", function()
    M.show_body_editor()
  end, opts)

  -- Copy as cURL
  popup:map("n", "c", function()
    local curl_cmd = M.build_curl_string()
    vim.fn.setreg("+", curl_cmd)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " cURL copied! " })
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = 16,
      height = 1,
      row = math.floor(vim.o.lines / 2),
      col = math.floor((vim.o.columns - 16) / 2),
      style = "minimal",
      border = "rounded",
      zindex = 200,
    })
    vim.api.nvim_buf_add_highlight(buf, -1, "RestischSuccess", 0, 0, -1)
    vim.api.nvim_set_option_value("winhighlight", "FloatBorder:RestischSuccess", { win = win })
    vim.defer_fn(function()
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end, 1500)
  end, opts)

  -- Send request
  popup:map("n", "<CR>", function()
    M.send_request()
  end, opts)
end

-- Show method selection menu
function M.show_method_menu()
  local items = vim.tbl_map(function(m)
    return Menu.item(m)
  end, M.methods)

  local menu = Menu({
    position = {
      row = 1,
      col = 1,
    },
    relative = "cursor",
    size = {
      width = 12,
      height = #M.methods,
    },
    border = {
      style = "rounded",
      text = {
        top = " Method ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:RestischBorder,CursorLine:Visual",
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "q" },
      submit = { "<CR>" },
    },
    on_submit = function(item)
      M.state.method = item.text
      M.render()
    end,
  })

  menu:mount()
end

-- Show URL input
function M.show_url_input()
  local input = Input({
    position = "50%",
    size = {
      width = 60,
    },
    border = {
      style = "rounded",
      text = {
        top = " URL ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder",
    },
  }, {
    prompt = "",
    default_value = M.state.url,
    on_submit = function(value)
      M.state.url = value
      M.render()
    end,
  })

  input:mount()
  input:map("n", "<Esc>", function()
    input:unmount()
  end, { noremap = true })
end

-- Show add header dialog
function M.show_add_header()
  local autocomplete_menu = nil
  local selected_index = 1
  local user_navigated = false
  local augroup = vim.api.nvim_create_augroup("RestischHeaderAutocomplete", { clear = true })
  local prompt_prefix = "Name: "

  -- Filter headers based on input
  local function filter_headers(text)
    if not text or text == "" then
      return common_headers
    end
    local lower_input = text:lower()
    local filtered = {}
    for _, header in ipairs(common_headers) do
      if header:lower():find(lower_input, 1, true) then
        table.insert(filtered, header)
      end
    end
    return filtered
  end

  -- Forward declaration
  local key_input
  local input_win
  local input_buf

  -- Cleanup function
  local function cleanup()
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    if autocomplete_menu then
      pcall(function() autocomplete_menu:unmount() end)
      autocomplete_menu = nil
    end
  end

  -- Accept autocomplete selection
  local function accept_selection()
    if autocomplete_menu and autocomplete_menu._items and #autocomplete_menu._items > 0 then
      local selected = autocomplete_menu._items[selected_index]
      local full_line = prompt_prefix .. selected
      vim.api.nvim_buf_set_lines(input_buf, 0, 1, false, { full_line })
      vim.api.nvim_win_set_cursor(input_win, { 1, #full_line })
      autocomplete_menu:unmount()
      autocomplete_menu = nil
      return true
    end
    return false
  end

  -- Create autocomplete popup
  local function show_autocomplete(filtered)
    if autocomplete_menu then
      pcall(function() autocomplete_menu:unmount() end)
      autocomplete_menu = nil
    end

    if #filtered == 0 then
      return
    end

    -- Limit to 8 items
    local display_items = {}
    for i = 1, math.min(8, #filtered) do
      table.insert(display_items, filtered[i])
    end

    selected_index = 1

    autocomplete_menu = Popup({
      position = {
        row = 2,
        col = 0,
      },
      relative = {
        type = "win",
        winid = input_win,
      },
      size = {
        width = 43,
        height = #display_items,
      },
      border = {
        style = "rounded",
      },
      win_options = {
        winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder",
      },
      buf_options = {
        modifiable = false,
      },
    })

    autocomplete_menu:mount()

    -- Render items
    local function render_menu()
      if not autocomplete_menu or not autocomplete_menu.bufnr then return end
      pcall(function()
        vim.bo[autocomplete_menu.bufnr].modifiable = true
        local lines = {}
        for i, item in ipairs(display_items) do
          if i == selected_index then
            table.insert(lines, " > " .. item)
          else
            table.insert(lines, "   " .. item)
          end
        end
        vim.api.nvim_buf_set_lines(autocomplete_menu.bufnr, 0, -1, false, lines)

        -- Highlight selected line
        for i = 1, #display_items do
          if i == selected_index then
            vim.api.nvim_buf_add_highlight(autocomplete_menu.bufnr, -1, "Visual", i - 1, 0, -1)
          end
        end
        vim.bo[autocomplete_menu.bufnr].modifiable = false
      end)
    end

    render_menu()

    -- Store display_items and render function for navigation
    autocomplete_menu._items = display_items
    autocomplete_menu._render = render_menu
  end

  -- Show value input after header name is entered
  local function open_value_input(header_name)
    cleanup()
    key_input:unmount()

    vim.schedule(function()
      local value_input = Input({
        position = "50%",
        size = { width = 50 },
        border = {
          style = "rounded",
          text = { top = " Add Header ", top_align = "center" },
        },
        win_options = {
          winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder",
        },
      }, {
        prompt = "Value: ",
        on_submit = function(value)
          table.insert(M.state.headers, { key = header_name, value = value or "" })
          M.render()
        end,
      })

      value_input:mount()

      -- Enter insert mode after a short delay to ensure window is ready
      vim.defer_fn(function()
        if value_input.winid and vim.api.nvim_win_is_valid(value_input.winid) then
          vim.api.nvim_set_current_win(value_input.winid)
          vim.cmd("startinsert!")
        end
      end, 10)

      value_input:map("n", "<Esc>", function()
        value_input:unmount()
      end, { noremap = true })

      value_input:map("i", "<Esc>", function()
        vim.cmd("stopinsert")
        value_input:unmount()
      end, { noremap = true })
    end)
  end

  -- First ask for header name
  key_input = Input({
    position = "50%",
    size = { width = 45 },
    border = {
      style = "rounded",
      text = { top = " Add Header ", top_align = "center" },
    },
    win_options = {
      winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder",
    },
  }, {
    prompt = "Name: ",
    on_submit = function(key)
      if key and key ~= "" then
        open_value_input(key)
      else
        cleanup()
      end
    end,
  })

  key_input:mount()
  vim.cmd("startinsert")

  input_win = key_input.winid
  input_buf = key_input.bufnr

  -- Handle text changes for autocomplete
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = augroup,
    buffer = input_buf,
    callback = function()
      user_navigated = false
      local line = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or ""
      -- Strip the prompt prefix if present
      if line:sub(1, #prompt_prefix) == prompt_prefix then
        line = line:sub(#prompt_prefix + 1)
      end
      local filtered = filter_headers(line)
      show_autocomplete(filtered)
    end,
  })

  -- Show initial autocomplete
  vim.schedule(function()
    if input_win and vim.api.nvim_win_is_valid(input_win) then
      show_autocomplete(common_headers)
    end
  end)

  -- Navigation keymaps
  key_input:map("i", "<Tab>", function()
    if autocomplete_menu and autocomplete_menu._items then
      local items = autocomplete_menu._items
      selected_index = selected_index % #items + 1
      autocomplete_menu._render()
    end
  end, { noremap = true })

  key_input:map("i", "<S-Tab>", function()
    if autocomplete_menu and autocomplete_menu._items then
      local items = autocomplete_menu._items
      selected_index = selected_index - 1
      if selected_index < 1 then
        selected_index = #items
      end
      autocomplete_menu._render()
    end
  end, { noremap = true })

  key_input:map("i", "<Down>", function()
    if autocomplete_menu and autocomplete_menu._items then
      local items = autocomplete_menu._items
      selected_index = selected_index % #items + 1
      user_navigated = true
      autocomplete_menu._render()
    end
  end, { noremap = true })

  key_input:map("i", "<Up>", function()
    if autocomplete_menu and autocomplete_menu._items then
      local items = autocomplete_menu._items
      selected_index = selected_index - 1
      if selected_index < 1 then
        selected_index = #items
      end
      user_navigated = true
      autocomplete_menu._render()
    end
  end, { noremap = true })

  -- Accept selection with Right arrow
  key_input:map("i", "<Right>", function()
    accept_selection()
  end, { noremap = true })

  -- Enter: accept dropdown selection if navigated, otherwise submit normally
  key_input:map("i", "<CR>", function()
    vim.cmd("stopinsert")
    if autocomplete_menu and autocomplete_menu._items and #autocomplete_menu._items > 0 and user_navigated then
      local selected = autocomplete_menu._items[selected_index]
      cleanup()
      key_input:unmount()
      vim.schedule(function()
        open_value_input(selected)
      end)
    else
      local line = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or ""
      if line:sub(1, #prompt_prefix) == prompt_prefix then
        line = line:sub(#prompt_prefix + 1)
      end
      cleanup()
      key_input:unmount()
      if line ~= "" then
        vim.schedule(function()
          open_value_input(line)
        end)
      end
    end
  end, { noremap = true })

  -- Close keymaps
  key_input:map("n", "<Esc>", function()
    cleanup()
    key_input:unmount()
  end, { noremap = true })

  key_input:map("i", "<Esc>", function()
    vim.cmd("stopinsert")
    cleanup()
    key_input:unmount()
  end, { noremap = true })
end

-- Delete header at cursor position
function M.delete_header_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local header_start_line = M.state.header_start_line or 6
  local header_index = line_num - header_start_line + 1

  if header_index >= 1 and header_index <= #M.state.headers then
    table.remove(M.state.headers, header_index)
    M.render()
  end
end

-- Show body editor
function M.show_body_editor()
  local popup = Popup({
    position = "50%",
    size = {
      width = 70,
      height = 20,
    },
    border = {
      style = "rounded",
      text = {
        top = " Body (JSON) - <C-s> to save, <Esc> to cancel ",
        top_align = "center",
      },
    },
    buf_options = {
      filetype = "json",
    },
    win_options = {
      winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder",
    },
    enter = true,
  })

  popup:mount()

  -- Disable auto-indent to preserve user's formatting
  vim.bo[popup.bufnr].autoindent = false
  vim.bo[popup.bufnr].smartindent = false
  vim.bo[popup.bufnr].cindent = false
  vim.bo[popup.bufnr].indentexpr = ""

  -- Set initial content
  local body_lines = vim.split(M.state.body, "\n")
  if #body_lines == 1 and body_lines[1] == "" then
    body_lines = { "{", "  ", "}" }
  end
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, body_lines)

  -- Position cursor
  vim.api.nvim_win_set_cursor(popup.winid, { 2, 2 })

  -- Save keymap
  popup:map("n", "<C-s>", function()
    local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    M.state.body = table.concat(lines, "\n")
    popup:unmount()
    M.render()
  end, { noremap = true })

  popup:map("i", "<C-s>", function()
    vim.cmd("stopinsert")
    local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    M.state.body = table.concat(lines, "\n")
    popup:unmount()
    M.render()
  end, { noremap = true })

  -- Cancel keymap
  popup:map("n", "<Esc>", function()
    popup:unmount()
  end, { noremap = true })

  -- Enter insert mode
  vim.cmd("startinsert")
end

-- Build a cURL command string from current state
function M.build_curl_string()
  local parts = { "curl" }

  if M.state.method ~= "GET" then
    table.insert(parts, "-X " .. M.state.method)
  end

  for _, h in ipairs(M.state.headers) do
    if h.key and h.key ~= "" then
      table.insert(parts, string.format("-H '%s: %s'", h.key, h.value or ""))
    end
  end

  local body_methods = { POST = true, PUT = true, PATCH = true, DELETE = true }
  if body_methods[M.state.method] and M.state.body and #M.state.body > 0 then
    local escaped_body = M.state.body:gsub("'", "'\\''")
    table.insert(parts, string.format("-d '%s'", escaped_body))
  end

  local url = M.state.url
  if url ~= "" and not url:match("^https?://") then
    url = "https://" .. url
  end
  table.insert(parts, "'" .. url .. "'")

  return table.concat(parts, " \\\n  ")
end

-- Send the request
function M.send_request()
  if M.state.on_send then
    M.state.on_send({
      method = M.state.method,
      url = M.state.url,
      headers = M.state.headers,
      body = M.state.body,
    })
  end
end

-- Get current request state
function M.get_state()
  return {
    method = M.state.method,
    url = M.state.url,
    headers = vim.deepcopy(M.state.headers),
    body = M.state.body,
  }
end

-- Set request state (for loading saved requests)
function M.set_state(data)
  M.state.method = data.method or "GET"
  M.state.url = data.url or "https://"
  M.state.headers = vim.deepcopy(data.headers or {})
  M.state.body = data.body or ""
  M.render()
end

-- Reset state
function M.reset()
  local config = require("restisch.config").get()
  M.state.method = "GET"
  M.state.url = ""
  M.state.headers = vim.deepcopy(config.default_headers or {})
  M.state.body = ""
end

return M
