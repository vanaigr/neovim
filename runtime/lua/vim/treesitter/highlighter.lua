local api = vim.api
local query = vim.treesitter.query
local Range = require('vim.treesitter._range')

local ns = api.nvim_create_namespace('treesitter/highlighter')


---@param priorities { [1]: integer, [2]: integer }
local function add_priority(priorities, pred)
  if pred[1] ~= 'set!' or pred[2] ~= 'priority' then
    return
  end

  ---@type integer
  local priority
  if type(pred[3]) == 'string' then
    priority = tonumber(pred[3])
  else
    priority = tonumber(pred[4])
  end

  if priorities[1] > priority then
    priorities[1] = priority
  end
  if priorities[2] < priority then
    priorities[2] = priority
  end
end

---@alias vim.treesitter.highlighter.Iter fun(end_line: integer|nil): integer, TSNode, vim.treesitter.query.TSMetadata, TSQueryMatch

---@class (private) vim.treesitter.highlighter.Query
---@field private _query vim.treesitter.Query?
---@field private lang string
---@field private hl_cache table<integer,integer>
---@field priorities { [1]: integer, [2]: integer }
local TSHighlighterQuery = {}
TSHighlighterQuery.__index = TSHighlighterQuery

---@private
---@param lang string
---@param query_string string?
---@return vim.treesitter.highlighter.Query
function TSHighlighterQuery.new(lang, query_string)
  local self = setmetatable({}, TSHighlighterQuery)
  self.lang = lang
  self.hl_cache = {}

  if query_string then
    self._query = query.parse(lang, query_string)
  else
    self._query = query.get(lang, 'highlights')
  end

  local priorities = { vim.hl.priorities.treesitter, vim.hl.priorities.treesitter }

  local patterns = self._query.info.patterns
  for _, preds in pairs(patterns) do
    for _, pred in ipairs(preds) do
      add_priority(priorities, pred)
    end
  end

  -- for spell offset
  priorities[2] = priorities[2] + 1
  self.priorities = priorities

  return self
end

---@package
---@param capture integer
---@return integer?
function TSHighlighterQuery:get_hl_from_capture(capture)
  if not self.hl_cache[capture] then
    local name = self._query.captures[capture]
    local id = 0
    if not vim.startswith(name, '_') then
      id = api.nvim_get_hl_id_by_name('@' .. name .. '.' .. self.lang)
    end
    self.hl_cache[capture] = id
  end

  return self.hl_cache[capture]
end

---@nodoc
function TSHighlighterQuery:query()
  return self._query
end

---@nodoc
---@class vim.treesitter.highlighter
---@field active table<integer,vim.treesitter.highlighter>
---@field bufnr integer
---@field private orig_spelloptions string
--- A map of highlight states.
--- This state is kept during rendering across each line update.
---@field private _highlight_state vim.treesitter.highlighter.State
---@field private _queries table<string,vim.treesitter.highlighter.Query>
---@field tree vim.treesitter.LanguageTree
---@field private redraw_count integer
local TSHighlighter = {
  active = {},
}

TSHighlighter.__index = TSHighlighter

---@nodoc
---
--- Creates a highlighter for `tree`.
---
---@param tree vim.treesitter.LanguageTree parser object to use for highlighting
---@param opts (table|nil) Configuration of the highlighter:
---           - queries table overwrite queries used by the highlighter
---@return vim.treesitter.highlighter Created highlighter object
function TSHighlighter.new(tree, opts)
  local self = setmetatable({}, TSHighlighter)

  if type(tree:source()) ~= 'number' then
    error('TSHighlighter can not be used with a string parser source.')
  end

  opts = opts or {} ---@type { queries: table<string,string> }
  self.tree = tree
  tree:register_cbs({
    on_detach = function()
      self:on_detach()
    end,
  })

  tree:register_cbs({
    on_changedtree = function(...)
      self:on_changedtree(...)
    end,
    on_child_removed = function(child)
      child:for_each_tree(function(t)
        self:on_changedtree(t:included_ranges(true))
      end)
    end,
  }, true)

  local source = tree:source()
  assert(type(source) == 'number')

  self.bufnr = source
  self.redraw_count = 0
  self._highlight_states = {}
  self._queries = {}

  -- Queries for a specific language can be overridden by a custom
  -- string query... if one is not provided it will be looked up by file.
  if opts.queries then
    for lang, query_string in pairs(opts.queries) do
      self._queries[lang] = TSHighlighterQuery.new(lang, query_string)
    end
  end

  self.orig_spelloptions = vim.bo[self.bufnr].spelloptions

  vim.bo[self.bufnr].syntax = ''
  vim.b[self.bufnr].ts_highlight = true

  TSHighlighter.active[self.bufnr] = self

  -- Tricky: if syntax hasn't been enabled, we need to reload color scheme
  -- but use synload.vim rather than syntax.vim to not enable
  -- syntax FileType autocmds. Later on we should integrate with the
  -- `:syntax` and `set syntax=...` machinery properly.
  -- Still need to ensure that syntaxset augroup exists, so that calling :destroy()
  -- immediately afterwards will not error.
  if vim.g.syntax_on ~= 1 then
    vim.cmd.runtime({ 'syntax/synload.vim', bang = true })
    vim.api.nvim_create_augroup('syntaxset', { clear = false })
  end

  vim._with({ buf = self.bufnr }, function()
    vim.opt_local.spelloptions:append('noplainbuffer')
  end)

  self.tree:parse()

  return self
end

--- @nodoc
--- Removes all internal references to the highlighter
function TSHighlighter:destroy()
  TSHighlighter.active[self.bufnr] = nil

  if api.nvim_buf_is_loaded(self.bufnr) then
    vim.bo[self.bufnr].spelloptions = self.orig_spelloptions
    vim.b[self.bufnr].ts_highlight = nil
    if vim.g.syntax_on == 1 then
      api.nvim_exec_autocmds('FileType', { group = 'syntaxset', buffer = self.bufnr })
    end
  end
end

---@class (private) vim.treesitter.highlighter.TreeInfo
---@field tstree TSTree
---@field next_row integer
---@field iter vim.treesitter.highlighter.Iter
---@field second_layer_nodes TSNode[]

---@class (private) vim.treesitter.highlighter.TreesInfo
---@field highlighter_query vim.treesitter.highlighter.Query
---@field priorities { [1]: integer, [2]: integer }[]
---@field trees vim.treesitter.highlighter.TreeInfo[]

---@class (private) vim.treesitter.highlighter.State
---@field total_priorities integer
---@field trees_info? vim.treesitter.highlighter.TreesInfo
---@field child_states vim.treesitter.highlighter.State[]
---@field child_off integer

---@param langtree vim.treesitter.LanguageTree
---@param opts table
---@return vim.treesitter.highlighter.State
function TSHighlighter:compute_hl_state(langtree, opts)
  local max_child_priorities = 0
  local child_states = {}
  for _, child in pairs(langtree._children) do
    local state = self:compute_hl_state(child, opts)
    max_child_priorities = math.max(max_child_priorities, state.total_priorities)
    table.insert(child_states, state)
  end

  local total_priorities = max_child_priorities
  local child_off = 0

  local query = self:get_query(langtree:lang())

  ---@type vim.treesitter.highlighter.TreesInfo
  local trees_info
  if query then
    local trees = {}
    for _, tstree in pairs(langtree._trees) do
      if tstree then
        local root_node = tstree:root()
        local root_start_row, _, root_end_row, _ = root_node:range()
        if root_end_row >= opts.srow and root_start_row <= opts.erow then
          table.insert(trees, {
            tstree = tstree,
            next_row = 0,
            iter = nil,
            second_layer_nodes = {},
          })
        end
      end
    end

    if #trees ~= 0 then
      local priorities = query.priorities
      local priorities_count = (priorities[2] - priorities[1] + 1)

      total_priorities = total_priorities + priorities_count

      trees_info = {
        highlighter_query = query,
        priorities = priorities,
        trees = trees,
      }
      child_off = priorities_count
    end
  end

  return {
    total_priorities = total_priorities,
    trees_info = trees_info,
    child_states = child_states,
    child_off = child_off,
  }
end

---@param srow integer
---@param erow integer exclusive
---@private
function TSHighlighter:prepare_highlight_states(srow, erow)
  self._highlight_state = self:compute_hl_state(
    self.tree,
    { srow = srow, erow = erow }
  )
end

---@package
function TSHighlighter:on_detach()
  self:destroy()
end

---@package
---@param changes Range6[]
function TSHighlighter:on_changedtree(changes)
  for _, ch in ipairs(changes) do
    api.nvim__redraw({ buf = self.bufnr, range = { ch[1], ch[4] + 1 }, flush = false })
  end
end

--- Gets the query used for @param lang
---@nodoc
---@param lang string Language used by the highlighter.
---@return vim.treesitter.highlighter.Query
function TSHighlighter:get_query(lang)
  if not self._queries[lang] then
    self._queries[lang] = TSHighlighterQuery.new(lang)
  end

  return self._queries[lang]
end

--- @param match TSQueryMatch
--- @param bufnr integer
--- @param capture integer
--- @param metadata vim.treesitter.query.TSMetadata
--- @return string?
local function get_url(match, bufnr, capture, metadata)
  ---@type string|number|nil
  local url = metadata[capture] and metadata[capture].url

  if not url or type(url) == 'string' then
    return url
  end

  local captures = match:captures()

  if not captures[url] then
    return
  end

  -- Assume there is only one matching node. If there is more than one, take the URL
  -- from the first.
  local other_node = captures[url][1]

  return vim.treesitter.get_node_text(other_node, bufnr, {
    metadata = metadata[url],
  })
end

--- @param capture_name string
--- @return boolean?, integer
local function get_spell(capture_name)
  if capture_name == 'spell' then
    return true, 0
  elseif capture_name == 'nospell' then
    -- Give nospell a higher priority so it always overrides spell captures.
    return false, 1
  end
  return nil, 0
end

---@param trees vim.treesitter.highlighter.TreesInfo
---@param state vim.treesitter.highlighter.TreeInfo
---@param priority_off integer
---@param second_layer table[]
---@param opts table
local function hl_tree(trees, state, priority_off, second_layer, opts)
  local root_node = state.tstree:root()
  local root_start_row, _, root_end_row, _ = root_node:range()

  -- Only consider trees that contain this line
  if root_start_row > opts.line or root_end_row < opts.line then
    return
  end

  if state.iter == nil or state.next_row < opts.line then
    -- Mainly used to skip over folds

    -- TODO(lewis6991): Creating a new iterator loses the cached predicate results for query
    -- matches. Move this logic inside iter_captures() so we can maintain the cache.
    state.iter = trees.highlighter_query:query():iter_captures(root_node, opts.buf, opts.line, root_end_row + 1)
  end

  while opts.line >= state.next_row do
    local capture, node, metadata, match = state.iter(opts.line)

    local range = { root_end_row + 1, 0, root_end_row + 1, 0 }
    if node then
      range = vim.treesitter.get_range(node, opts.buf, metadata and metadata[capture])
    end
    local start_row, start_col, end_row, end_col = Range.unpack4(range)

    if capture then
      local hl = trees.highlighter_query:get_hl_from_capture(capture)

      local capture_name = trees.highlighter_query:query().captures[capture]

      local spell, spell_pri_offset = get_spell(capture_name)

      -- The "priority" attribute can be set at the pattern level or on a particular capture
      local priority = (
        tonumber(metadata.priority or metadata[capture] and metadata[capture].priority)
        or vim.hl.priorities.treesitter
      ) + spell_pri_offset

      -- The "conceal" attribute can be set at the pattern level or on a particular capture
      local conceal = metadata.conceal or metadata[capture] and metadata[capture].conceal
      local url = get_url(match, opts.buf, capture, metadata)

      print(priority - trees.priorities[1] + priority_off)
      if hl and end_row >= opts.line and (not opts.is_spell_nav or spell ~= nil) then
        api.nvim_buf_set_extmark(opts.buf, ns, start_row, start_col, {
          end_line = end_row,
          end_col = end_col,
          hl_group = hl,
          ephemeral = true,
          priority = priority - trees.priorities[1] + priority_off,
          conceal = conceal,
          spell = spell,
          url = url,
        })
      end
    end

    if start_row > opts.line then
      state.next_row = start_row
    end
  end
end

---@param state vim.treesitter.highlighter.State
---@param priority_off integer
---@param opts table
local function highlight(state, priority_off, opts)
  print('--', priority_off)
  local second_layer = {}
  for _, tstree in ipairs(state.trees_info.trees) do
    hl_tree(state.trees_info, tstree, priority_off, second_layer, opts)
  end
  local child_priority_off = priority_off + state.child_off
  for _, child in ipairs(state.child_states) do
    highlight(child, child_priority_off, opts)
  end
end

---@param self vim.treesitter.highlighter
---@param buf integer
---@param line integer
---@param is_spell_nav boolean
local function on_line_impl(self, buf, line, is_spell_nav)
  local opts = { self = self, buf = buf, line = line, is_spell_nav = is_spell_nav }
  highlight(self._highlight_state, vim.highlight.priorities.treesitter, opts)
end

---@private
---@param _win integer
---@param buf integer
---@param line integer
function TSHighlighter._on_line(_, _win, buf, line, _)
  local self = TSHighlighter.active[buf]
  if not self then
    return
  end

  on_line_impl(self, buf, line, false)
end

---@private
---@param buf integer
---@param srow integer
---@param erow integer
function TSHighlighter._on_spell_nav(_, _, buf, srow, _, erow, _)
  local self = TSHighlighter.active[buf]
  if not self then
    return
  end

  -- Do not affect potentially populated highlight state. Here we just want a temporary
  -- empty state so the C code can detect whether the region should be spell checked.
  local highlight_states = self._highlight_states
  self:prepare_highlight_states(srow, erow)

  for row = srow, erow do
    on_line_impl(self, buf, row, true)
  end
  self._highlight_states = highlight_states
end

---@private
---@param _win integer
---@param buf integer
---@param topline integer
---@param botline integer
function TSHighlighter._on_win(_, _win, buf, topline, botline)
  local self = TSHighlighter.active[buf]
  if not self then
    return false
  end
  self.tree:parse({ topline, botline + 1 })
  self:prepare_highlight_states(topline, botline + 1)
  self.redraw_count = self.redraw_count + 1
  return true
end

api.nvim_set_decoration_provider(ns, {
  on_win = TSHighlighter._on_win,
  on_line = TSHighlighter._on_line,
  _on_spell_nav = TSHighlighter._on_spell_nav,
})

return TSHighlighter
