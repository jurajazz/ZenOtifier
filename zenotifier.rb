require 'rbconfig'
require_relative 'lib/events'
require_relative 'lib/time_conversions'
#require 'ruby-debug'

host_os = RbConfig::CONFIG['host_os']
case host_os
when /mswin|msys|mingw|cygwin|bccwin|wince|emc/; os = 'windows';
when /darwin|mac os/;os = 'macosx';
when /linux/;os = 'linux';end
puts "OS:#{os}"

# this is user interface for events notification
Shoes.app :height=>230 do
  #Shoes::show_console
  @events = Events.new
  @events.source_file = "#{ENV['HOME']}/.zenotifier/events.yaml"
  @events.target_file = @events.source_file
  @events.load
  @last_notification_time=0 # last notification time
  edits=Hash.new
  set_window_title('Zenotifier')
  tagline "New Event:"
  stack do
    flow do para "What";   edits['what'] = edit_line
      para "(Call Mike)"; end
    flow do para "When";   edits['when'] = edit_line
      para "([after] 15min, 2day, 1mon, 2018-01-31, 15:40)"; end
    flow do para "Notify"; edits['notify'] = edit_line
      para "(30min, 1hour, 2day, 1mon [before])"; end
    flow do para "Repeat"; edits['repeat'] = edit_line
      para "([every] 1day, 2week, 3mon, 1year)"; end
    start do
      edits['what'].focus()
    end
    finish do
        puts "Main window finish"
    end
    button "Create" do
      @events.add_from_edits(edits) and alert "Event created"
    end
  end

  animate(1) do
    if @events.notification_is_shown
      t = TimeConversions.new.get_now_sec
      if t-@last_notification_time > 30
         system "notify-send \"#{@event.what}\""
         @last_notification_time = t
      end
    else
      @event = @events.check_from_gui(TimeConversions.new.get_now_sec)
      if @event
        puts "Show notification window with event"
        @events.open_notification
        show_window(@events)
      end
    end
  end # animate

  def show_window(events)
    puts "show_window"
    window :height=>200 do
      e = events.event_beeing_notified
      stack do
        para "#{e.what}"
        @def = button "Snooze (1 day)" do
          e.do_snooze(60*60*24,0)
          events.close_notification
          close
        end
        flow do
          para "Snooze time (30min)"
          @snooze_time = edit_line
          button "Snooze" do
            time = TimeConversions.new.parse_rel_time_str(@snooze_time.text)
            puts "Snooze time #{time} sec"
            return if !time
            e.do_snooze(time,0)
            events.close_notification
            close
          end
        end
        start do @def.focus; end
        finish do
          events.close_notification
        end
        if e.should_repeat
          button "Done (repeat: #{e.repeat})" do
            e.do_repeat
            events.close_notification
            close
          end
          button "Done (no repeat)" do
            return if !confirm("Are you sure this event should NOT repeat anymore?")
            e.do_mark_as_complete(0)
            events.close_notification
            close
          end
        end
        button "Done" do
          e.do_mark_as_complete(0)
          events.close_notification
          close
        end
      end
    end # window
  end
end
