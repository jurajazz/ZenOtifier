#/usr/bin/ruby
require 'yaml'
require 'rbconfig'
require_relative 'lib/events'
require_relative 'lib/time_conversions'
require_relative 'lib/timer'

# global vars
$datadir = "#{ENV['HOME']}/.zenotifier"
$events = Events.new
$height_main_window = 220

class NotifConfiguration
  attr_accessor :ui,:color_background,:color_font,:gui_for_beginners

  def initialize
		@gui_for_beginners = false
    @config_file = "#{$datadir}/config.yaml"
    puts "Config file #{@config_file}"
    if !File.exist?(@config_file)
      # auto create default config file in user's profile
      Dir.mkdir($datadir)
      data = File.read('profile/default/config.yaml')
      File.write(@config_file,data)
    end
    @config = YAML.load_file(@config_file) or return
    puts "Config #{@config}"
    @ui = @config['user interface'] or return
		gui_for_beginners = @ui['gui_for_beginners']
		@gui_for_beginners=true if gui_for_beginners
    theme_name = @ui['theme']
    if theme_name and theme_name.length
      # load colors
      @ui['themes'].each do |th|
        next if th['name'] != theme_name
        @color_background = "##{th['back']}"
        @color_font = "##{th['font']}"
      end
    end
    $height_main_window -= 30 if !@ui['form field notify display']
  end
end

$config = NotifConfiguration.new

# this is user interface for events notification
Shoes.app :height=>$height_main_window do

  # check OS type
  case RbConfig::CONFIG['host_os']
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/; @os = 'windows';
    when /darwin|mac os/;@os = 'macosx';
    when /linux/;@os = 'linux';
  end

  $events.verbose = 1
  style Shoes::Para, stroke: $config.color_font
  background $config.color_background
  $events.source_file = "#{$datadir}/events.yaml"
  if !File.exist?($events.source_file)
    # auto create default event file in user's profile
    data = File.read('profile/default/events.yaml')
    File.write($events.source_file,data)
  end

  $events.target_file = $events.source_file
  $events.load
  @check_timer = NTimer.new(2)
  @check_timer.set_to_expire
  notif_highlight_period = $config.ui['flashing reminder period seconds'].to_i
  notif_highlight_period = 60 if notif_highlight_period.nil? or notif_highlight_period<1
  @highlight_notif_timer = NTimer.new(notif_highlight_period)
  @next_time_range_sec = 60*60*24*3
  @last_notification_time=0 # last notification time
  @edits=Hash.new
  set_window_title('ZenOtifier')
  keypress do |k|
     puts "Keypress -#{k}-"
     if k == "\n"
       create_clicked
     end
     if k.to_s == "alt_e"
       edit_all_events
     end
     if k.to_s == "alt_o"
       open_edit_event
     end
  end
  @top = 7; @line_h = 30;
  @edit_left = 70; @edit_width = 200
  @desc_left = @edit_left+@edit_width
  @desc_right = @desc_left+300
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
        next if i[1]=='notify' and !$config.ui['form field notify display']
        p = para i[0], :top => @top
        if i[1] == 'description'
          @descr_check = check do
            if @descr_check.checked
              @edits['description'].show
            else
              @edits['description'].hide
            end
          end
          @descr_check.style :top => @top, :left => 45
          @edits[i[1]] = edit_box :left=> @edit_left, :width=>@desc_right-@edit_left, :height => 40, :top => @top
          @edits[i[1]].hide
        else
          @edits[i[1]] = edit_line :left=> @edit_left, :width=>@edit_width, top: @top
					if $config.gui_for_beginners
            t = para i[2]; t.style :left => @desc_left, top: @top
					end
        end
        @top += @line_h
      end
    end
    @top += @line_h
    flow do
      button "Create", :top => @top, :left => 5 do
        create_clicked
      end
      button "Edit all Events", :top => @top, :left => 100 do
        edit_all_events
      end
    end
    @next_info = flow do
      #@next_progress = progress width: 0.5, top: @top, left:@desc_left
      @event_text = para "in 1d: Event", top: @top, left: @desc_left
      @next_edit = button "Open", top: @top, left:@desc_right-50 do
        open_edit_event
      end
    end
    @next_info.hide
    start do
      puts "Start"
      @edits['what'].focus()
      @edits['description'].hide
    end
    finish do
        puts "Main window finish"
    end
  end

  # kind of mainloop
  animate(1) do
    now = TimeConversions.new.get_now_sec
    next if !@check_timer.expired
    @check_timer.arm
    if $events.notification_is_shown
			@check_timer.set_period(2)
      if @highlight_notif_timer.expired
        @highlight_notif_timer.arm
        message = "#{@event.what}"
        puts "Show notification period:#{@highlight_notif_timer.period_sec()}sec #{message}" if $events.verbose>0
        if @os == 'linux'
          # based on ubuntu tool: notify-send
          system "notify-send \"#{message} (by ZenOtifier)\"" if @os == 'linux'
        elsif @os == 'windows'
          # based on notifu tool: https://www.paralint.com/projects/notifu
          system "notifu /q /p ZenOtifier /m \"#{message}\" /d 2000"
        end
      end
    else
      @event = $events.get_next_event_2b_notified(now)
      if @event
        puts "Show notification window with event"
        show_window(@event)
        @check_timer.set_to_expire
        next
			else
	      @event = $events.what_is_next(now, now + @next_time_range_sec)
	      if @event
	        time_to_notif = TimeConversions.new.get_sec_from_str(@event.notify_at) - now
	        time_to = "#{time_to_notif/60}min"
	        time_to = "#{time_to_notif/(60*60)}h" if time_to_notif>60*60*2
	        time_to = sprintf("%.1fd",time_to_notif.to_f/(60*60*24)) if time_to_notif>60*60*24
	        @event_text.text = "#{time_to}: #{@event.what}"
	        @next_info.show if $config.ui['show next event']
	      else
        	@next_info.hide
				end
				@check_timer.set_period(30)
      end
    end
  end # animate

  def edit_all_events
    if @os == 'linux'
      system "gedit #{$events.source_file}"
    elsif @os == 'windows'
      system "start #{$events.source_file}"
    end
  end

  def open_edit_event
    #visit('/snooze_event')
    show_window(@event)
  end

  def create_clicked
    if $events.add_from_edits(@edits)
      # clean @edits after created
      details = ''
      @edits.keys.each do |key|
        t = @edits[key].text; details += "\n#{key}:#{t}" if t.length>0
        @edits[key].text = ''
      end
      alert "Event created:#{details}"
    end
  end

  def show_window(event)
    puts "show_window"
    $events.open_notification
    window :height=>200, :width=>450 do
      @e = event
      set_window_title(@e.what)
      background $config.color_background
      style Shoes::Para, stroke: $config.color_font
      s = stack do
        flow do
          @snooze_time = edit_line width: 50
          default_period = $config.ui['default notify period']
          @snooze_time.text = default_period if default_period and default_period.length
          button "Snooze" do
            gui_snooze
          end
          para "(30min,1day,1week)" if $config.gui_for_beginners
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
          else
						# no repeat is defined
            button "Done" do
              @e.do_mark_as_complete(0)
              close
            end
					end
        end # flow
				# show information about remaining items
				if $events.remaining_items_2b_notified>1
				  t = para "Remaining: #{$events.remaining_items_2b_notified-1}"; #t.style :left => 10, top: 50
				end
        if @e.description.length>0
          flow do
            @edit_description = edit_box width: 300, height: 80
            @edit_description.text = "#{@e.description}"
            button "Save Descr" do
              @e.description = @edit_description.text
              puts "description #{@e.description} text:#{@edit_description.text}" if $events.verbose>0
            end
          end
        end # description
        # start event
        start do @snooze_time.focus; end
        # finish event
        finish do
          puts "Finishing notification window"
          $events.close_notification
        end
      end # stack
      keypress do |k|
         puts "Keypress -#{k}-"
         gui_snooze if k.to_s == "\n"
         if k.to_s == "alt_r"
           @e.do_repeat
           close
         end
         if k.to_s == "alt_d"
           @e.do_mark_as_complete(0)
           close
         end
      end

      def gui_snooze
        time = TimeConversions.new.parse_rel_time_str(@snooze_time.text)
        puts "Snooze time #{time} sec"
        return if !time
        @e.do_snooze(time,0)
        close
      end

			animate(1) do
				puts "Small Window Animate"
				if $events.is_source_file_changed_after_load
					puts "Closing small window due to source file changed"
					$events.load
					close
				end
			end

    end # window
  end # def show_window
end
