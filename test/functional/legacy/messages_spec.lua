local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local exec = n.exec
local feed = n.feed
local api = n.api
local nvim_dir = n.nvim_dir
local assert_alive = n.assert_alive

before_each(clear)

describe('messages', function()
  local screen

  -- oldtest: Test_warning_scroll()
  it('a warning causes scrolling if and only if it has a stacktrace', function()
    screen = Screen.new(75, 6)

    -- When the warning comes from a script, messages are scrolled so that the
    -- stacktrace is visible.
    -- It is a bit hard to assert the screen when sourcing a script, so skip this part.

    -- When the warning does not come from a script, messages are not scrolled.
    command('enew')
    command('set readonly')
    feed('u')
    screen:expect({
      grid = [[
                                                                                 |
      {1:~                                                                          }|*4
      {19:W10: Warning: Changing a readonly file}^                                     |
    ]],
      timeout = 500,
    })
    screen:expect([[
      ^                                                                           |
      {1:~                                                                          }|*4
      Already at oldest change                                                   |
    ]])
  end)

  -- oldtest: Test_message_not_cleared_after_mode()
  it('clearing mode does not remove message', function()
    screen = Screen.new(60, 10)
    exec([[
      nmap <silent> gx :call DebugSilent('normal')<CR>
      vmap <silent> gx :call DebugSilent('visual')<CR>
      function DebugSilent(arg)
          echomsg "from DebugSilent" a:arg
      endfunction
      set showmode
      set cmdheight=1
      call setline(1, ['one', 'NoSuchFile', 'three'])
    ]])

    feed('gx')
    screen:expect([[
      ^one                                                         |
      NoSuchFile                                                  |
      three                                                       |
      {1:~                                                           }|*6
      from DebugSilent normal                                     |
    ]])

    -- removing the mode message used to also clear the intended message
    feed('vEgx')
    screen:expect([[
      ^one                                                         |
      NoSuchFile                                                  |
      three                                                       |
      {1:~                                                           }|*6
      from DebugSilent visual                                     |
    ]])

    -- removing the mode message used to also clear the error message
    command('set cmdheight=2')
    feed('2GvEgf')
    screen:expect([[
      one                                                         |
      NoSuchFil^e                                                  |
      three                                                       |
      {1:~                                                           }|*5
                                                                  |
      {9:E447: Can't find file "NoSuchFile" in path}                  |
    ]])
  end)

  -- oldtest: Test_mode_cleared_after_silent_message()
  it('mode is cleared properly after silent message', function()
    screen = Screen.new(60, 10)
    exec([[
      edit XsilentMessageMode.txt
      call setline(1, 'foobar')
      autocmd TextChanged * silent update
    ]])
    finally(function()
      os.remove('XsilentMessageMode.txt')
    end)

    feed('v')
    screen:expect([[
      ^foobar                                                      |
      {1:~                                                           }|*8
      {5:-- VISUAL --}                                                |
    ]])

    feed('d')
    screen:expect([[
      ^oobar                                                       |
      {1:~                                                           }|*8
                                                                  |
    ]])
  end)

  describe('more prompt', function()
    before_each(function()
      command('set more')
    end)

    -- oldtest: Test_message_more()
    it('works', function()
      screen = Screen.new(75, 6)

      command('call setline(1, range(1, 100))')

      feed(':%pfoo<C-H><C-H><C-H>#')
      screen:expect([[
        1                                                                          |
        2                                                                          |
        3                                                                          |
        4                                                                          |
        5                                                                          |
        :%p#^                                                                       |
      ]])
      feed('\n')
      screen:expect([[
        {8:  1 }1                                                                      |
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {6:-- More --}^                                                                 |
      ]])

      feed('?')
      screen:expect([[
        {8:  1 }1                                                                      |
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {6:-- More -- SPACE/d/j: screen/page/line down, b/u/k: up, q: quit }^           |
      ]])

      -- Down a line with j, <CR>, <NL> or <Down>.
      feed('j')
      screen:expect([[
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {8:  6 }6                                                                      |
        {6:-- More --}^                                                                 |
      ]])
      feed('<NL>')
      screen:expect([[
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {8:  6 }6                                                                      |
        {8:  7 }7                                                                      |
        {6:-- More --}^                                                                 |
      ]])
      feed('<CR>')
      screen:expect([[
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {8:  6 }6                                                                      |
        {8:  7 }7                                                                      |
        {8:  8 }8                                                                      |
        {6:-- More --}^                                                                 |
      ]])
      feed('<Down>')
      screen:expect([[
        {8:  5 }5                                                                      |
        {8:  6 }6                                                                      |
        {8:  7 }7                                                                      |
        {8:  8 }8                                                                      |
        {8:  9 }9                                                                      |
        {6:-- More --}^                                                                 |
      ]])

      -- Down a screen with <Space>, f, or <PageDown>.
      feed('f')
      screen:expect([[
        {8: 10 }10                                                                     |
        {8: 11 }11                                                                     |
        {8: 12 }12                                                                     |
        {8: 13 }13                                                                     |
        {8: 14 }14                                                                     |
        {6:-- More --}^                                                                 |
      ]])
      feed('<Space>')
      screen:expect([[
        {8: 15 }15                                                                     |
        {8: 16 }16                                                                     |
        {8: 17 }17                                                                     |
        {8: 18 }18                                                                     |
        {8: 19 }19                                                                     |
        {6:-- More --}^                                                                 |
      ]])
      feed('<PageDown>')
      screen:expect([[
        {8: 20 }20                                                                     |
        {8: 21 }21                                                                     |
        {8: 22 }22                                                                     |
        {8: 23 }23                                                                     |
        {8: 24 }24                                                                     |
        {6:-- More --}^                                                                 |
      ]])

      -- Down a page (half a screen) with d.
      feed('d')
      screen:expect([[
        {8: 23 }23                                                                     |
        {8: 24 }24                                                                     |
        {8: 25 }25                                                                     |
        {8: 26 }26                                                                     |
        {8: 27 }27                                                                     |
        {6:-- More --}^                                                                 |
      ]])

      -- Down all the way with 'G'.
      feed('G')
      screen:expect([[
        {8: 96 }96                                                                     |
        {8: 97 }97                                                                     |
        {8: 98 }98                                                                     |
        {8: 99 }99                                                                     |
        {8:100 }100                                                                    |
        {6:Press ENTER or type command to continue}^                                    |
      ]])

      -- Up a line k, <BS> or <Up>.
      feed('k')
      screen:expect([[
        {8: 95 }95                                                                     |
        {8: 96 }96                                                                     |
        {8: 97 }97                                                                     |
        {8: 98 }98                                                                     |
        {8: 99 }99                                                                     |
        {6:-- More --}^                                                                 |
      ]])
      feed('<BS>')
      screen:expect([[
        {8: 94 }94                                                                     |
        {8: 95 }95                                                                     |
        {8: 96 }96                                                                     |
        {8: 97 }97                                                                     |
        {8: 98 }98                                                                     |
        {6:-- More --}^                                                                 |
      ]])
      feed('<Up>')
      screen:expect([[
        {8: 93 }93                                                                     |
        {8: 94 }94                                                                     |
        {8: 95 }95                                                                     |
        {8: 96 }96                                                                     |
        {8: 97 }97                                                                     |
        {6:-- More --}^                                                                 |
      ]])

      -- Up a screen with b or <PageUp>.
      feed('b')
      screen:expect([[
        {8: 88 }88                                                                     |
        {8: 89 }89                                                                     |
        {8: 90 }90                                                                     |
        {8: 91 }91                                                                     |
        {8: 92 }92                                                                     |
        {6:-- More --}^                                                                 |
      ]])
      feed('<PageUp>')
      screen:expect([[
        {8: 83 }83                                                                     |
        {8: 84 }84                                                                     |
        {8: 85 }85                                                                     |
        {8: 86 }86                                                                     |
        {8: 87 }87                                                                     |
        {6:-- More --}^                                                                 |
      ]])

      -- Up a page (half a screen) with u.
      feed('u')
      screen:expect([[
        {8: 80 }80                                                                     |
        {8: 81 }81                                                                     |
        {8: 82 }82                                                                     |
        {8: 83 }83                                                                     |
        {8: 84 }84                                                                     |
        {6:-- More --}^                                                                 |
      ]])

      -- Up all the way with 'g'.
      feed('g')
      screen:expect([[
        :%p#                                                                       |
        {8:  1 }1                                                                      |
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {6:-- More --}^                                                                 |
      ]])

      -- All the way down. Pressing f should do nothing but pressing
      -- space should end the more prompt.
      feed('G')
      screen:expect([[
        {8: 96 }96                                                                     |
        {8: 97 }97                                                                     |
        {8: 98 }98                                                                     |
        {8: 99 }99                                                                     |
        {8:100 }100                                                                    |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
      feed('f')
      screen:expect_unchanged()
      feed('<Space>')
      screen:expect([[
        96                                                                         |
        97                                                                         |
        98                                                                         |
        99                                                                         |
        ^100                                                                        |
                                                                                   |
      ]])

      -- Pressing g< shows the previous command output.
      feed('g<lt>')
      screen:expect([[
        {8: 96 }96                                                                     |
        {8: 97 }97                                                                     |
        {8: 98 }98                                                                     |
        {8: 99 }99                                                                     |
        {8:100 }100                                                                    |
        {6:Press ENTER or type command to continue}^                                    |
      ]])

      -- A command line that doesn't print text is appended to scrollback,
      -- even if it invokes a nested command line.
      feed([[:<C-R>=':'<CR>:<CR>g<lt>]])
      screen:expect([[
        {8: 97 }97                                                                     |
        {8: 98 }98                                                                     |
        {8: 99 }99                                                                     |
        {8:100 }100                                                                    |
        :::                                                                        |
        {6:Press ENTER or type command to continue}^                                    |
      ]])

      feed(':%p#\n')
      screen:expect([[
        {8:  1 }1                                                                      |
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {6:-- More --}^                                                                 |
      ]])

      -- Stop command output with q, <Esc> or CTRL-C.
      feed('q')
      screen:expect([[
        96                                                                         |
        97                                                                         |
        98                                                                         |
        99                                                                         |
        ^100                                                                        |
                                                                                   |
      ]])

      -- Execute a : command from the more prompt
      feed(':%p#\n')
      screen:expect([[
        {8:  1 }1                                                                      |
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        {6:-- More --}^                                                                 |
      ]])
      feed(':')
      screen:expect([[
        {8:  1 }1                                                                      |
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        :^                                                                          |
      ]])
      feed("echo 'Hello'\n")
      screen:expect([[
        {8:  2 }2                                                                      |
        {8:  3 }3                                                                      |
        {8:  4 }4                                                                      |
        {8:  5 }5                                                                      |
        Hello                                                                      |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    end)

    -- oldtest: Test_echo_verbose_system()
    it('verbose message before echo command', function()
      screen = Screen.new(60, 10)

      command('cd ' .. nvim_dir)
      api.nvim_set_option_value('shell', './shell-test', {})
      api.nvim_set_option_value('shellcmdflag', 'REP 20', {})
      api.nvim_set_option_value('shellxquote', '', {}) -- win: avoid extra quotes

      -- display a page and go back, results in exactly the same view
      feed([[:4 verbose echo system('foo')<CR>]])
      screen:expect([[
        Executing command: "'./shell-test' 'REP' '20' 'foo'"        |
                                                                    |
        0: foo                                                      |
        1: foo                                                      |
        2: foo                                                      |
        3: foo                                                      |
        4: foo                                                      |
        5: foo                                                      |
        6: foo                                                      |
        {6:-- More --}^                                                  |
      ]])
      feed('<Space>')
      screen:expect([[
        7: foo                                                      |
        8: foo                                                      |
        9: foo                                                      |
        10: foo                                                     |
        11: foo                                                     |
        12: foo                                                     |
        13: foo                                                     |
        14: foo                                                     |
        15: foo                                                     |
        {6:-- More --}^                                                  |
      ]])
      feed('b')
      screen:expect([[
        Executing command: "'./shell-test' 'REP' '20' 'foo'"        |
                                                                    |
        0: foo                                                      |
        1: foo                                                      |
        2: foo                                                      |
        3: foo                                                      |
        4: foo                                                      |
        5: foo                                                      |
        6: foo                                                      |
        {6:-- More --}^                                                  |
      ]])

      -- do the same with 'cmdheight' set to 2
      feed('q')
      command('set ch=2')
      screen:expect([[
        ^                                                            |
        {1:~                                                           }|*7
                                                                    |*2
      ]])
      feed([[:4 verbose echo system('foo')<CR>]])
      screen:expect([[
        Executing command: "'./shell-test' 'REP' '20' 'foo'"        |
                                                                    |
        0: foo                                                      |
        1: foo                                                      |
        2: foo                                                      |
        3: foo                                                      |
        4: foo                                                      |
        5: foo                                                      |
        6: foo                                                      |
        {6:-- More --}^                                                  |
      ]])
      feed('<Space>')
      screen:expect([[
        7: foo                                                      |
        8: foo                                                      |
        9: foo                                                      |
        10: foo                                                     |
        11: foo                                                     |
        12: foo                                                     |
        13: foo                                                     |
        14: foo                                                     |
        15: foo                                                     |
        {6:-- More --}^                                                  |
      ]])
      feed('b')
      screen:expect([[
        Executing command: "'./shell-test' 'REP' '20' 'foo'"        |
                                                                    |
        0: foo                                                      |
        1: foo                                                      |
        2: foo                                                      |
        3: foo                                                      |
        4: foo                                                      |
        5: foo                                                      |
        6: foo                                                      |
        {6:-- More --}^                                                  |
      ]])
    end)

    -- oldtest: Test_quit_long_message()
    it('with control characters can be quit vim-patch:8.2.1844', function()
      screen = Screen.new(40, 10)

      feed([[:echom range(9999)->join("\x01")<CR>]])
      screen:expect([[
        0{18:^A}1{18:^A}2{18:^A}3{18:^A}4{18:^A}5{18:^A}6{18:^A}7{18:^A}8{18:^A}9{18:^A}10{18:^A}11{18:^A}12|
        {18:^A}13{18:^A}14{18:^A}15{18:^A}16{18:^A}17{18:^A}18{18:^A}19{18:^A}20{18:^A}21{18:^A}22|
        {18:^A}23{18:^A}24{18:^A}25{18:^A}26{18:^A}27{18:^A}28{18:^A}29{18:^A}30{18:^A}31{18:^A}32|
        {18:^A}33{18:^A}34{18:^A}35{18:^A}36{18:^A}37{18:^A}38{18:^A}39{18:^A}40{18:^A}41{18:^A}42|
        {18:^A}43{18:^A}44{18:^A}45{18:^A}46{18:^A}47{18:^A}48{18:^A}49{18:^A}50{18:^A}51{18:^A}52|
        {18:^A}53{18:^A}54{18:^A}55{18:^A}56{18:^A}57{18:^A}58{18:^A}59{18:^A}60{18:^A}61{18:^A}62|
        {18:^A}63{18:^A}64{18:^A}65{18:^A}66{18:^A}67{18:^A}68{18:^A}69{18:^A}70{18:^A}71{18:^A}72|
        {18:^A}73{18:^A}74{18:^A}75{18:^A}76{18:^A}77{18:^A}78{18:^A}79{18:^A}80{18:^A}81{18:^A}82|
        {18:^A}83{18:^A}84{18:^A}85{18:^A}86{18:^A}87{18:^A}88{18:^A}89{18:^A}90{18:^A}91{18:^A}92|
        {6:-- More --}^                              |
      ]])
      feed('q')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*8
                                                |
      ]])
    end)
  end)

  describe('mode is cleared when', function()
    before_each(function()
      screen = Screen.new(40, 6)
    end)

    -- oldtest: Test_mode_message_at_leaving_insert_by_ctrl_c()
    it('leaving Insert mode with Ctrl-C vim-patch:8.1.1189', function()
      exec([[
        func StatusLine() abort
          return ""
        endfunc
        set statusline=%!StatusLine()
        set laststatus=2
      ]])
      feed('i')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*3
        {3:                                        }|
        {5:-- INSERT --}                            |
      ]])
      feed('<C-C>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*3
        {3:                                        }|
                                                |
      ]])
    end)

    -- oldtest: Test_mode_message_at_leaving_insert_with_esc_mapped()
    it('leaving Insert mode with ESC in the middle of a mapping vim-patch:8.1.1192', function()
      exec([[
        set laststatus=2
        inoremap <Esc> <Esc>00
      ]])
      feed('i')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*3
        {3:[No Name]                               }|
        {5:-- INSERT --}                            |
      ]])
      feed('<Esc>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*3
        {3:[No Name]                               }|
                                                |
      ]])
    end)

    -- oldtest: Test_mode_updated_after_ctrl_c()
    it('pressing Ctrl-C in i_CTRL-O', function()
      feed('i<C-O>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*4
        {5:-- (insert) --}                          |
      ]])
      feed('<C-C>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*4
                                                |
      ]])
    end)
  end)

  -- oldtest: Test_ask_yesno()
  it('y/n prompt works', function()
    screen = Screen.new(75, 6)
    command('set noincsearch nohlsearch inccommand=')
    command('call setline(1, range(1, 2))')

    feed(':2,1s/^/n/\n')
    screen:expect([[
      1                                                                          |
      2                                                                          |
      {1:~                                                                          }|*3
      {6:Backwards range given, OK to swap (y/n)?}^                                   |
    ]])
    feed('n')
    screen:expect([[
      ^1                                                                          |
      2                                                                          |
      {1:~                                                                          }|*3
      {6:Backwards range given, OK to swap (y/n)?}n                                  |
    ]])

    feed(':2,1s/^/Esc/\n')
    screen:expect([[
      1                                                                          |
      2                                                                          |
      {1:~                                                                          }|*3
      {6:Backwards range given, OK to swap (y/n)?}^                                   |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^1                                                                          |
      2                                                                          |
      {1:~                                                                          }|*3
      {6:Backwards range given, OK to swap (y/n)?}n                                  |
    ]])

    feed(':2,1s/^/y/\n')
    screen:expect([[
      1                                                                          |
      2                                                                          |
      {1:~                                                                          }|*3
      {6:Backwards range given, OK to swap (y/n)?}^                                   |
    ]])
    feed('y')
    screen:expect([[
      y1                                                                         |
      ^y2                                                                         |
      {1:~                                                                          }|*3
      {6:Backwards range given, OK to swap (y/n)?}y                                  |
    ]])
  end)

  -- oldtest: Test_fileinfo_tabpage_cmdheight()
  it("fileinfo works when 'cmdheight' has just decreased", function()
    screen = Screen.new(40, 6)

    exec([[
      set shortmess-=o
      set shortmess-=O
      set shortmess-=F
      tabnew
      set cmdheight=2
    ]])
    screen:expect([[
      {24: [No Name] }{5: [No Name] }{2:                 }{24:X}|
      ^                                        |
      {1:~                                       }|*2
                                              |*2
    ]])

    feed(':tabprev | edit Xfileinfo.txt<CR>')
    screen:expect([[
      {5: Xfileinfo.txt }{24: [No Name] }{2:             }{24:X}|
      ^                                        |
      {1:~                                       }|*3
      "Xfileinfo.txt" [New]                   |
    ]])
    assert_alive()
  end)

  -- oldtest: Test_fileinfo_after_echo()
  it('fileinfo does not overwrite echo message vim-patch:8.2.4156', function()
    screen = Screen.new(40, 6)

    exec([[
      set shortmess-=F

      file a.txt

      hide edit b.txt
      call setline(1, "hi")
      setlocal modified

      hide buffer a.txt

      autocmd CursorHold * buf b.txt | w | echo "'b' written"

      set updatetime=50
      normal! 0$
    ]])

    screen:expect([[
      ^hi                                      |
      {1:~                                       }|*4
      'b' written                             |
    ]])
    os.remove('b.txt')
  end)

  -- oldtest: Test_messagesopt_wait()
  it('&messagesopt "wait"', function()
    screen = Screen.new(45, 6)
    command('set cmdheight=1')

    -- Check hit-enter prompt
    command('set messagesopt=hit-enter,history:500')
    feed(":echo 'foo' | echo 'bar' | echo 'baz'\n")
    screen:expect([[
                                                   |
      {3:                                             }|
      foo                                          |
      bar                                          |
      baz                                          |
      {6:Press ENTER or type command to continue}^      |
    ]])
    feed('<CR>')

    -- Check no hit-enter prompt when "wait:" is set
    command('set messagesopt=wait:500,history:500')
    feed(":echo 'foo' | echo 'bar' | echo 'baz'\n")
    screen:expect({
      grid = [[
                                                   |
      {1:~                                            }|
      {3:                                             }|
      foo                                          |
      bar                                          |
      baz                                          |
    ]],
      timeout = 500,
    })
    screen:expect([[
      ^                                             |
      {1:~                                            }|*4
                                                   |
    ]])
  end)
end)
