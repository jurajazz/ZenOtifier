require 'rbconfig'
require_relative 'lib/events'
require_relative 'lib/time_conversions'

# check OS type
case RbConfig::CONFIG['host_os']
when /mswin|msys|mingw|cygwin|bccwin|wince|emc/; os = 'windows';
when /darwin|mac os/;os = 'macosx';
when /linux/;os = 'linux';end

# this is user interface for events notification
Shoes.app :height=>230 do
  @events = Events.new
  @events.verbose = 1
  @events.source_file = "#{ENV['HOME']}/.zenotifier/events.yaml"
  @events.target_file = @events.source_file
  @events.load
  @last_notification_time=0 # last notification time
  edits=Hash.new
  set_window_title('ZenOtifier')
  @edit_left = 60; @edit_width = 200
  @desc_left = @edit_left+@edit_width
  @desc_right = @desc_left+300
  #self.style :width => 100, :height => 100
  stack do
    items = [
      ['What','what','(Call Mike)'],
      ['When','when','([after] 15min, 2day, 1mon, 2018-01-31, 15:40)'],
      ['Notify','notify','(30min, 1hour, 2days, 1month [before])'],
      ['Repeat','repeat','([every] 1day, 2week, 3month, 1year)'],
      ['Descr','description',''],
    ]
    items.each do |i|
      flow do
        para i[0];
        if i[1] == 'description'
          @descr_check = check do
            if @descr_check.checked
              edits['description'].show
            else
              edits['description'].hide
            end
          end
          edits[i[1]] = edit_box :left=> @edit_left, :width=>@desc_right-@edit_left, height: 40
          edits[i[1]].hide
        else
          edits[i[1]] = edit_line :left=> @edit_left, :width=>@edit_width
          t = para i[2]; t.style :left => @desc_left
        end
      end
    end
    flow do
      button "Create" do
        @events.add_from_edits(edits) and alert "Event created"
      end
      button "Edit all Events" do
        if os == 'linux'
          system "gedit #{@events.source_file}"
        elsif os == 'windows'
          system "start #{@events.source_file}"
        end
      end
    end
    start do
      puts "Start"
      edits['what'].focus()
      edits['description'].hide
    end
    finish do
        puts "Main window finish"
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
    window :height=>200, :width=>450 do
      @e = events.event_beeing_notified
      set_window_title(@e.what)
      stack do
        flow do
          @snooze_time = edit_line width: 50
          button "Snooze" do
            time = TimeConversions.new.parse_rel_time_str(@snooze_time.text)
            puts "Snooze time #{time} sec"
            return if !time
            @e.do_snooze(time,0)
            close
          end
          para "(30min,1day,1week)"
          if @e.should_repeat
            button "Done (repeat: #{@e.repeat})" do
              @e.do_repeat
              close
            end
            button "Done (no repeat)" do
              return if !confirm("Are you sure this event should NOT repeat anymore?")
              @e.do_mark_as_complete(0)
              close
            end
          end
          button "Done" do
            @e.do_mark_as_complete(0)
            close
          end
        end # flow
        if @e.description.length>0
          flow do
            @edit_description = edit_box width: 300, height: 80
            @edit_description.text = "#{@e.description}"
            button "Save Descr" do
              @e.description = @edit_description.text
              puts "description #{@e.description} text:#{@edit_description.text}" if events.verbose>0
            end
          end
        end # description
        # start event
        start do @snooze_time.focus; end
        # finish event
        finish do
          puts "Finishing notification window"
          events.close_notification
        end
      end # stack
    end # window
  end # def show_window
end
