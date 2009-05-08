#!/usr/bin/env ruby
#Author: Roy L Zuo (roylzuo at gmail dot com)
#Last Change: Tue Apr 21 10:14:38 2009 EST
#Description: NCurses interface classes
require 'ncurses'
require 'config.rb'

class Window
    attr_reader :w, :h
    attr_accessor :xoffset, :yoffset

    def initialize(x, y, col, row)
        @win = Ncurses.newwin(row, col, y, x)
        @w = col
        @h = row
        @xoffset = 3
        @yoffset = 3
        if $use_ascii 
            @win.border ?|, ?|, ?-, ?-, ?+, ?+, ?+, ?+
        else
            @win.box 0,0
        end
        @win.refresh
    end

    def title(string)
        #set title
        @win.mvprintw  0, 2, " #{string} "
        @win.refresh
    end

    def draw_text(string, x=@xoffset, y=@yoffset, refresh=true)
        #write text on this window
        string.each_line { |l| 
            l = l.chomp
            @win.mvprintw y, x, l[0..@w-x-1]
        }
        @win.refresh        if refresh
    end

    def refresh()           @win.refresh        end 
end

class CUI
    def initialize
        #init screen
        @rootw = Ncurses.initscr
        Ncurses.cbreak
        Ncurses.curs_set 0
        @rootw.mvaddstr     0, 1, "RememberTheCow  #{$version} | q:quit  i:select  DEL:delete"
        @rootw.refresh

        # get screen dimensions
        h = []; w = []
        Ncurses::getmaxyx Ncurses::stdscr, h, w
        @h = h[0] - 1 
        @w = w[0]

        @xoffset=$xoffset
        @yoffset=$yoffset

        #initialize task & info windows
        info_width = @w/5*2 > 36 ? @w*2/5 : 36
        @taskw = Window.new(0,1,@w - info_width,@h)
        @taskw.title('Inbox')
        @infow = Window.new(@w-info_width,1,info_width,@h)
        @infow.title('Task Details')

        #initialize rtm
        @rtm = RTM.new($api_key, $shared_secret, $token)

        #get tasks in Inbox
        filter='status:incomplete"'
        lists = @rtm.lists.getList['lists']['list'] 
        lidx = lists.index{|i| i['name'].casecmp('Inbox') == 0} 
        lid = lists[lidx]['id'] 
        tasks = @rtm.tasks.getList({'list_id'=>lid, 'filter'=>filter})

        tl = []
        mkArray( tasks['tasks']['list'] ).each { |l| 
            mkArray( l['taskseries'] ).each { |s|
                mkArray( s['task'] ).each { |t|     tl << s['name'] }
            }
        }

        line = 0
        tl.each { |str| 
            @taskw.draw_text(str, @taskw.xoffset, @taskw.yoffset+line, false)
            line += 1
        }
        @taskw.refresh

        Ncurses.getch

        #main_loop
    end

end

#if __FILE__ == $0
    #begin
        #CUI.new
    #ensure
        #Ncurses::endwin
    #end
#end
