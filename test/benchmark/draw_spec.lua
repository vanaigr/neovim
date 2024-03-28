local helpers = require('test.functional.helpers')(after_each)
local api = helpers.api
local Screen = require('test.functional.ui.screen')

local width, height = 100, 100

local function make_lines(char)
  local line = char:rep(width)
  local lines = {}
  for i = 1, height do
    table.insert(lines, line)
  end
  return lines
end

local function benchmark(lines, grid)
  local screen = Screen.new(width, height + 1)
  screen:attach()

  api.nvim_buf_set_lines(0, 0, 1, false, lines)
  screen:expect{grid=grid}

  local N = 1000
  local time = helpers.exec_lua(
    [==[
    local N = ...
    local time = {}
    for i = 1, N do
      local s = vim.uv.hrtime()
      vim.cmd('redraw!')
      local e = vim.uv.hrtime()
      table.insert(time, e - s)
    end
    return time
    ]==],
    N
  )

  table.sort(time)

  local us = 1 / 1000
  print(
    string.format(
      'min, 25%%, median, 75%%, max:\n\t%0.2fus,\t%0.2fus,\t%0.2fus,\t%0.2fus,\t%0.2fus',
      time[1] * us,
      time[1 + math.floor(#time * 0.25)] * us,
      time[1 + math.floor(#time * 0.5)] * us,
      time[1 + math.floor(#time * 0.75)] * us,
      time[#time] * us
    )
  )
end

describe('draw the screen', function()
  before_each(helpers.clear)
  it('with ascii', function()
      local char = 'a'
      local lines = make_lines(char)
      local grid = [[
        ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|*99
                                                                                                            |
      ]]

      benchmark(lines, grid)
  end)

  it('with 2-byte UTF-8', function()
      local line = ('\xC9\x91'):rep(width)
      local lines = {}
      for i = 1, height do
        table.insert(lines, line)
      end

      local grid = [[
        ^ɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑ|
        ɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑɑ|*99
                                                                                                            |
      ]]

      benchmark(lines, grid)
  end)

  it('with ascii and combining character', function()
      local line = ('a\xCC\x8F'):rep(width)
      local lines = {}
      for i = 1, height do
        table.insert(lines, line)
      end
      local grid = [[
        ^ȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁ|
        ȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁȁ|*99
                                                                                                            |
      ]]

      benchmark(lines, grid)
  end)

  it('with 2-byte UTF-8 and combining character', function()
      local line = ('\xC9\x91\xCC\x8F'):rep(width)
      local lines = {}
      for i = 1, height do
        table.insert(lines, line)
      end
      local grid = [[
        ^ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏|
        ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏ɑ̏|*99
                                                                                                            |
      ]]

      benchmark(lines, grid)
  end)

  it('with ascii and 7 combining characters', function()
      local line = ('\x61\xCC\x80\xCC\x82\xCC\x84\xCC\x86\xCC\x88\xCC\x8A\xCC\x89'):rep(width)
      local lines = {}
      for i = 1, height do
        table.insert(lines, line)
      end
      -- only first 6 are shown
      local grid = [[
        ^à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊|
        à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊à̂̄̆̈̊|*99
                                                                                                            |
      ]]

      benchmark(lines, grid)
  end)
end)
