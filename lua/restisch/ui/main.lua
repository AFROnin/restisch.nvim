-- RESTisch main window module
local Layout = require("nui.layout")
local Menu = require("nui.menu")

local M = {}

-- Current state
M.state = {
  layout = nil,
  request_panel = nil,
  response_panel = nil,
  is_open = false,
}

-- Request history (last 20)
M.history = {}

-- Open the main RESTisch window
function M.open()
  if M.state.is_open then
    M.focus()
    return
  end

  local config = require("restisch.config").get()
  local request_ui = require("restisch.ui.request")
  local response_ui = require("restisch.ui.response")
  local http = require("restisch.http")

  -- Create panels
  local request_panel = request_ui.create(function(request_data)
    -- Send callback
    response_ui.show_loading()
    http.request(request_data, function(response)
      response_ui.set_response(response)
      -- Add to history
      local entry = {
        method = request_data.method,
        url = request_data.url,
        status = response.status or 0,
        time = os.date("%H:%M:%S"),
      }
      table.insert(M.history, 1, entry)
      if #M.history > 20 then
        table.remove(M.history)
      end
    end)
  end)

  local response_panel = response_ui.create()

  -- Store references
  M.state.request_panel = request_panel
  M.state.response_panel = response_panel

  -- Create layout
  local layout = Layout(
    {
      position = "50%",
      size = {
        width = config.width,
        height = config.height,
      },
    },
    Layout.Box({
      Layout.Box(request_panel, { size = "31%" }),
      Layout.Box(response_panel, { size = "69%" }),
    }, { dir = "col" })
  )

  M.state.layout = layout

  -- Mount the layout
  layout:mount()
  M.state.is_open = true

  -- Render initial content
  request_ui.render()
  response_ui.render()

  -- Setup keymaps
  request_ui.setup_keymaps()
  response_ui.setup_keymaps()

  -- Setup global keymaps for both panels
  M.setup_global_keymaps(request_panel)
  M.setup_global_keymaps(response_panel)

  -- Focus the request panel
  if request_panel.winid and vim.api.nvim_win_is_valid(request_panel.winid) then
    vim.api.nvim_set_current_win(request_panel.winid)
    M.update_panel_borders("request")
  end
end

-- Setup global keymaps (applied to both panels)
function M.setup_global_keymaps(popup)
  if not popup then
    return
  end

  local opts = { noremap = true, nowait = true }
  local dialogs = require("restisch.ui.dialogs")
  local request_ui = require("restisch.ui.request")

  -- Close window
  popup:map("n", "q", function()
    M.close()
  end, opts)

  popup:map("n", "<Esc>", function()
    if request_ui.state.editing_url then
      return
    end
    M.close()
  end, opts)

  -- Save request
  popup:map("n", "<C-s>", function()
    local request_data = request_ui.get_state()
    dialogs.save_dialog(request_data)
  end, opts)

  -- Load request
  popup:map("n", "<C-o>", function()
    dialogs.load_dialog(function(data)
      request_ui.set_state(data)
    end)
  end, opts)

  -- Switch between panels
  popup:map("n", "<Tab>", function()
    M.toggle_focus()
  end, opts)

  popup:map("n", "<S-Tab>", function()
    M.toggle_focus()
  end, opts)

  -- New request
  popup:map("n", "<C-n>", function()
    request_ui.reset()
    request_ui.render()
    require("restisch.ui.response").clear()
  end, opts)

  -- Request history
  popup:map("n", "<C-h>", function()
    M.show_history()
  end, opts)
end

-- Update panel border highlights to indicate active panel
function M.update_panel_borders(active_panel)
  local request_panel = M.state.request_panel
  local response_panel = M.state.response_panel

  if not request_panel or not response_panel then
    return
  end

  local active = active_panel == "request" and request_panel or response_panel
  local inactive = active_panel == "request" and response_panel or request_panel
  local active_label = active_panel == "request" and " ● Request " or " ● Response "
  local inactive_label = active_panel == "request" and " Response " or " Request "

  if active.winid and vim.api.nvim_win_is_valid(active.winid) then
    vim.api.nvim_set_option_value("winhighlight",
      "Normal:Normal,FloatBorder:RestischBorderActive", { win = active.winid })
    pcall(vim.api.nvim_win_set_config, active.winid, {
      title = { { active_label, "RestischBorderActive" } },
      title_pos = "center",
    })
  end
  if inactive.winid and vim.api.nvim_win_is_valid(inactive.winid) then
    vim.api.nvim_set_option_value("winhighlight",
      "Normal:Normal,FloatBorder:RestischBorder", { win = inactive.winid })
    pcall(vim.api.nvim_win_set_config, inactive.winid, {
      title = { { inactive_label, "RestischBorder" } },
      title_pos = "center",
    })
  end
end

-- Toggle focus between panels
function M.toggle_focus()
  local request_panel = M.state.request_panel
  local response_panel = M.state.response_panel

  if not request_panel or not response_panel then
    return
  end

  local current_win = vim.api.nvim_get_current_win()

  if current_win == request_panel.winid then
    if response_panel.winid and vim.api.nvim_win_is_valid(response_panel.winid) then
      vim.api.nvim_set_current_win(response_panel.winid)
      M.update_panel_borders("response")
    end
  else
    if request_panel.winid and vim.api.nvim_win_is_valid(request_panel.winid) then
      vim.api.nvim_set_current_win(request_panel.winid)
      M.update_panel_borders("request")
    end
  end
end

-- Show request history picker
function M.show_history()
  if #M.history == 0 then
    vim.notify("No request history yet", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, entry in ipairs(M.history) do
    local status_str = entry.status > 0 and tostring(entry.status) or "ERR"
    local label = string.format("[%s] %s %s  %s", entry.time, entry.method, entry.url, status_str)
    table.insert(items, Menu.item(label, { data = entry }))
  end

  local menu = Menu({
    position = "50%",
    size = {
      width = 80,
      height = math.min(#items, 15),
    },
    border = {
      style = "rounded",
      text = {
        top = " Request History ",
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
      local request_ui = require("restisch.ui.request")
      request_ui.state.method = item.data.method
      request_ui.state.url = item.data.url
      request_ui.render()
    end,
  })

  menu:mount()
end

-- Focus the RESTisch window
function M.focus()
  local request_panel = M.state.request_panel
  if request_panel and request_panel.winid and vim.api.nvim_win_is_valid(request_panel.winid) then
    vim.api.nvim_set_current_win(request_panel.winid)
  end
end

-- Close the RESTisch window
function M.close()
  -- Close any open dialogs first
  require("restisch.ui.dialogs").close_all()

  if M.state.layout then
    M.state.layout:unmount()
  end

  M.state.layout = nil
  M.state.request_panel = nil
  M.state.response_panel = nil
  M.state.is_open = false

  -- Reset request state for next open
  require("restisch.ui.request").reset()
  require("restisch.ui.response").clear()
end

-- Toggle the RESTisch window
function M.toggle()
  if M.state.is_open then
    M.close()
  else
    M.open()
  end
end

-- Check if window is open
function M.is_open()
  return M.state.is_open
end

return M
