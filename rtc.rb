#!/usr/bin/env ruby
#Author: Roy L Zuo (roylzuo at gmail dot com)
#Last Change: Fri Apr 17 16:06:18 2009 EST
#Description: main script of Remember the Cow
$LOAD_PATH << File.dirname(File.readlink($0))       if File.symlink?($0)
require 'api.rb'
require 'cli.rb'
require 'cui.rb'

if __FILE__==$0
    if ARGV.length > 0 
        t = CLI.new(rtm = RTM.new($api_key, $shared_secret, $token))
        t.callCmd(ARGV)
    else
        begin
            CUI.new
        rescue Timeout::Error
            exit
        #rescue
            #exit
        ensure
            Ncurses::endwin
        end
    end
end
