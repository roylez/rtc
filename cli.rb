#!/usr/bin/env ruby
#Author: Roy L Zuo (roylzuo at gmail dot com)
#Last Change: Mon Apr 20 16:23:11 2009 EST
#Description: 
#       This scripts emulates rtm's twitter IM commands. For more information,
#       go to http://www.rememberthemilk.com/services/twitter/ .
#
require 'api.rb'
require 'time'
require 'config.rb'

def assert(bool, msg)
    raise "Assertion failed! #{msg}" if not bool
end

class CLI

    def initialize(rtm) @rtm = rtm  end

    def callCmd(args)
        #parse command line options and call corresponding rtm twitter command, if possible
        cmd = {
                'add'=>:add,'a' => :add, 
                'addtag' => :addtag, 't' => :addtag,
                'complete' => :complete, 'c' => :complete,
                'delete' => :delete, 'd' => :delete,
                'postpone' => :postpone, 'p' => :postpone,
                'today' => :today, 'tod' => :today,
                'tomorrow' => :tomorrow, 'tom' => :tomorrow,
                'getdue' => :getdue, 'gd' => :getdue,
                'getlist'=>:getlist, 'gl'=>:getlist,
                'getlocation' => :getlocation, 'go' => :getlocation,
                'gettag' => :gettag, 'gt' => :gettag,
                'setdue' => :setdue, 'sd' => :setdue,
                'help' => :help, 'h' => :help,
                'version' => :version, 'v' => :version,
            }
        if args.length == 0
            p "Oops, curses interface not implemented!"
            exit     
        end
        assert(cmd.key?(args[0]), "Error: #{args[0]} is not a valid operation")
        if args.length == 1
            self.send(cmd[args[0]])
        else
            self.send(cmd[args[0]],*args[1..-1]) 
        end
    end
end

    def add(*args)
        if args.join(' ').include?('-')
            tags, name = args.join(' ').split('-')
            tags = tags.strip.gsub(/\s+/,',')
        else
            tags = nil
            name = args.join(' ')
        end
        priority = tags ? tags.split(/,|(?:\s+)/) & ['1','2','3'] : nil
        tags = tags.split(/,|(?:\s+)/) - priority      if priority
        res = @rtm.tasks.add({'name'=>name, 'timeline'=>@rtm.timelines.create['timeline'], 'parse'=>'1'})
        #set due if there is absent
        if res['list']['taskseries']['task']['due'] == ''
            @rtm.tasks.setDueDate({
                'timeline'=>@rtm.timelines.create['timeline'],
                'list_id' =>res['list']['id'],
                'taskseries_id' => res['list']['taskseries']['id'],
                'task_id' => res['list']['taskseries']['task']['id'],
                'due' => 'today',
                'parse' => '1',
            } )
        end
        if tags
            @rtm.tasks.addTags({'timeline'=>@rtm.timelines.create['timeline'],
                    'list_id' =>res['list']['id'],
                    'taskseries_id' => res['list']['taskseries']['id'],
                    'task_id' => res['list']['taskseries']['task']['id'],
                    'tags' =>tags     })
        end
        if priority and not priority.empty?
            @rtm.tasks.setPriority({'timeline'=>@rtm.timelines.create['timeline'],
                    'list_id' =>res['list']['id'],
                    'taskseries_id' => res['list']['taskseries']['id'],
                    'task_id' => res['list']['taskseries']['task']['id'],
                    'priority' =>priority     })
        end
    end

    def addtag(lastid, *tags)
        #also sets priority
        priority = tags ? tags & ['1','2','3'] : nil
        tags = tags - priority      if priority
        lastlist = (File.zero?($last_list) ? {} : YAML.load_file($last_list))
        assert(lastlist.key?(lastid), "Assertion Failed: incorrect task id.")
        @rtm.tasks.addTags({'timeline'=>@rtm.timelines.create['timeline'],
                    'list_id'=>lastlist[lastid][0],
                    'taskseries_id'=>lastlist[lastid][1],
                    'task_id'=>lastlist[lastid][2],
                    'tags' =>tags.join(',')     })
        if priority and not priority.empty?
            @rtm.tasks.setPriority({'timeline'=>@rtm.timelines.create['timeline'],
                    'list_id'=>lastlist[lastid][0],
                    'taskseries_id'=>lastlist[lastid][1],
                    'task_id'=>lastlist[lastid][2],
                    'priority' =>priority     })
        end
    end

    def complete(*lastid)
        lastlist = (File.zero?($last_list) ? {} : YAML.load_file($last_list))
        lastid.each { |id|
            if lastlist.key?(id)
                @rtm.tasks.complete({'timeline'=>@rtm.timelines.create['timeline'],
                            'list_id'=>lastlist[id][0],
                            'taskseries_id'=>lastlist[id][1],
                            'task_id'=>lastlist[id][2]  })
                lastlist.delete(id)
            end 
        }
        open($last_list,'w') { |f| f.puts lastlist.to_yaml }
    end

    def delete(*lastid)
        lastlist = (File.zero?($last_list) ? {} : YAML.load_file($last_list))
        lastid.each { |id|
            if lastlist.key?(id)
                @rtm.tasks.delete({'timeline'=>@rtm.timelines.create['timeline'],
                            'list_id'=>lastlist[id][0],
                            'taskseries_id'=>lastlist[id][1],
                            'task_id'=>lastlist[id][2]  })
                lastlist.delete(id)
            end 
        }
        open($last_list,'w') { |f| f.puts lastlist.to_yaml }
    end

    def help
        #print usage
        puts "Usage:    #{File.basename($0)} COMMAND [ARGUMENTS...]"
        puts
        puts "Commands:"
        cmds = [
            'add / a            add a new task, default due is today',
            'addtag / t         add tags to a specific task',
            'complete / c       use last listing\'s id number to mark specified tasks as completed',
            'delete / d         use last listing\'s id number to delete tasks',
            'getdue / gd        get tasks due within a time horizon, say "3 days of today"' ,
            'getlist / gl       get tasks due in two weeks',
            'gettag / gt        get a list of incomplete tasks with specific tags',
            'getlocation / go   get tasks to be complete at a specific place',
            'postpone / p       use last listing\'s id number to postpone specified tasks',
            'setdue / sd        set/change due time of a specified task',
            'today / tod        get tasks due in today',
            'tomorrow / tom     get tasks due within tomorrow',
            'help / h           print this message',
            'version / v        print version information',
        ]
        cmds.each {|c| puts "    #{c}"}
    end

    def getdue(*args)
        #get tasks due on a specific date
        #TODO maybe thereis a way to specify a due day to show.....
        tasks = @rtm.tasks.getList({'filter'=>"status:incomplete AND dueWithin:\"#{args.join(' ')}\""})
        ppTaskSeries( tasks['tasks'] )      if tasks['tasks'] != []
    end

    def getlist(list='Inbox')
        #return tasks in a specific list due with in two weeks, 
        #and overdue ones as well 
        #TODO put filter in options
        filter='status:incomplete AND dueBefore:"14 days of today"'
        lists = @rtm.lists.getList['lists']['list'] 
        lidx = lists.index{|i| i['name'].casecmp(list) == 0} 
        assert(lidx, "Invalid list name.")

        lid = lists[lidx]['id'] 
        tasks = @rtm.tasks.getList({'list_id'=>lid, 'filter'=>filter})
        ppTaskSeries( tasks['tasks'] )      if tasks['tasks'] != []
    end
    def gettag(*tags)
        #get tasks with tags
        ltag = []
        tags.each {|t| ltag << "tag: #{t}"}
        tagfilter = ltag.join(' OR ')
        tasks = @rtm.tasks.getList({'filter'=>"status:incomplete AND (#{tagfilter})"})
        ppTaskSeries( tasks['tasks'] )      if tasks['tasks'] != []
    end
    def getlocation(location)
        #get a list of tasks to be complete in a specific location
        tasks = @rtm.tasks.getList({'filter'=>"status:incomplete AND location:\"#{location}\""})
        ppTaskSeries( tasks['tasks'] )      if tasks['tasks'] != []
    end
    def postpone(*lastid)
        lastlist = (File.zero?($last_list) ? {} : YAML.load_file($last_list))
        lastid.each { |id| 
            #assert(lastlist.key?(lastid), "Assertion Failed: incorrect task id.")
            if lastlist.key?(id)
                @rtm.tasks.postpone({'timeline'=>@rtm.timelines.create['timeline'],
                            'list_id'=>lastlist[id][0],
                            'taskseries_id'=>lastlist[id][1],
                            'task_id'=>lastlist[id][2]  })
                lastlist.delete(id)
            end
        }
        open($last_list,'w') { |f| f.puts lastlist.to_yaml }
    end
    def setdue(lastid, *due)
        #set due time of a job
        lastlist = (File.zero?($last_list) ? {} : YAML.load_file($last_list))
        @rtm.tasks.setDueDate({'timeline'=>@rtm.timelines.create['timeline'],
                    'list_id'=>lastlist[lastid][0],
                    'taskseries_id'=>lastlist[lastid][1],
                    'task_id'=>lastlist[lastid][2],
                    'due' => due.join(' '),
                    'parse' => '1', })
        lastlist.delete(lastid)
        open($last_list,'w') { |f| f.puts lastlist.to_yaml }
    end
    def today
        #print tasks due in today
        tasks = @rtm.tasks.getList({'filter'=>"status:incomplete AND dueBefore:tomorrow"})
        ppTaskSeries( tasks['tasks'] )      if tasks['tasks'] != []
    end
    def tomorrow
        #print tasks due in today
        tasks = @rtm.tasks.getList({'filter'=>'status:incomplete AND dueWithin:"2 days of today"'})
        ppTaskSeries( tasks['tasks'] )      if tasks['tasks'] != []
    end
    def version
        #prints version information
        puts " ___________________________"
        puts "( RememberTheCow verion #{$version} )"
        puts " ---------------------------"
        puts "       o   ,__,"
        puts "        o  (oo)____"
        puts "           (__)    )\\"
        puts "              ||--|| *"
    end

def ppTaskSeries( tlist )
    i = 1
    lastlist = {}
    mkArray(tlist['list']).each do |l|
        #in case that only one task presents
        #taskseries that repeats have multiple task entries
        #a new array of tasks is created to take care of that
        tasks = []
        mkArray(l['taskseries']).each { |x|
            mkArray(x['task']).each { |t|
                h = {'name'=>x['name'], 'tsid'=>x['id']}
                h['rrule'] = x['rrule'] if x.key?('rrule')
                h['tag'] = x['tags']['tag']     if x['tags'] != []
                tasks << t.merge(h)
            }
        }

        #convert time to local
        tasks.each { |t| 
            t['due'] = Time.parse(t['due']).localtime       if t['due'] != ''
            t['added'] = Time.parse(t['added']).localtime       if t['added'] != ''
        }

        #sort by due day, has_due_time, and due time
        tasks.sort! {|x,y| 
            [Date.parse(x['due'].to_s), y['has_due_time'], x['due'] ] <=> \
            [Date.parse(y['due'].to_s), x['has_due_time'], y['due'] ]       }

        tasks.each { |t| 
            dt = t['due']
            dd = Date.parse(dt.to_s)
            if t['has_due_time']=='1' and dd==Date.today
                date = $c[:today] + dt.strftime("%H:%M %a") + $c[:reset]
            elsif dd == Date.today
                date = $c[:today] + dt.strftime('%m-%d %a') + $c[:reset]
            else
                date = dt.strftime('%m-%d %a')
            end
            priority = t['priority']=='N'?'':$c[:priority][t['priority']]
            repeat = t.key?('rrule') ? $c[:repeat]: ' '
            overdue = (dd < Date.today or (dt < Time.now and t['has_due_time']=='1')) ? $c[:overdue]:''
            today = dd == Date.today ? $c[:today] : ''
            tags = t.key?('tag') ? ($c[:tag]+mkArray(t['tag']).join(',')+"#{$c[:reset]}  ") : ''

            puts "%-4d%s %s%s%s  %s%s%s%s%s"\
                % [i, date, priority, repeat, $c[:reset], 
                    tags, overdue, today, t['name'],$c[:reset]]

            lastlist[i.to_s] = [l['id'], t['tsid'], t['id']]
            i += 1
        }
    end
    open($last_list,'w') { |f| f.puts lastlist.to_yaml }
end

def mkArray(obj)
    #sometimes json returns hash or string instead of array when there is only one value,
    #this method just wrapper over the value to ensure the returned value is an array
    obj.class == Array ? obj : [obj]
end

if __FILE__==$0
    rtm = RTM.new($api_key, $shared_secret, $token)
    t = CLI.new(rtm)
    t.getlist(ARGV[0]) 
end
