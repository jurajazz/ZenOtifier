# this code is for parsing, storing and evaluating events

require 'yaml'
require_relative 'time_conversions'

# ---------------------------------------------------------
# one event
# works only in absolute seconds unit
# ---------------------------------------------------------
class Event
  attr_accessor :what,:when,:notify_at,:notify_before,:repeat,:description,:completed,:changed,:index
  def initialize
    @what=''             # string describing the event
    @description=''      # string with additional details
    @when=''             # string when event should occour (e.g. '2018-01-31 15:00')
    @notify_at=''        # string when next notification will be fired (e.g. '2018-01-31 15:00')
    @notify_before=''    # string describing the time before 'when' when next notification will be planned (e.g. '1hour before')
    @repeat=''           # string describing the repeat period (e.g. 'every 2weeks')
    @completed = 0       # 1=completed - do not consider as active
    @conv = TimeConversions.new
    @changed = false     # true if event was change to storage (e.g. when)
		@index = 0           # referece to @events array
  end

  # used for parsing from yaml
  def from_hash(h,index)
    #puts "Event from_hash:#{h}"
    @what = h['what'] if h['what'].to_s.length>0
    @description = h['description'] if h['description'].to_s.length>0
    @when = h['when'].to_s if h['when'].to_s.length>0
    @notify_at = h['notify_at'].to_s if h['notify_at'].to_s.length>0
    @notify_before = h['notify_before'] if h['notify_before'].to_s.length>0
    @repeat = h['repeat'] if h['repeat'].to_s.length>0
    @completed = h['completed'] if h['completed'].to_s.length>0
		@index = index
  end

  # used for generating for yaml
  def to_hash
    res = {}
    res['what']=@what
    res['description']=@description if !@description.nil? and @description.length>0
    res['when']=@when
    res['notify_at']=@notify_at if (@notify_at.to_s.length>0)
    res['notify_before']=@notify_before if (@notify_before.to_s.length>0)
    res['repeat']=@repeat if (@repeat.to_s.length>0)
    res['completed']=@completed if (@completed>0)
    return res
  end

  # make snoose at defined time
  def do_snooze(sec,current_time)
     current_time = @conv.get_now_sec if current_time==0
     puts "Snooze current_time:#{@conv.get_str_from_sec(current_time)}"
     @notify_at = @conv.get_str_from_sec(current_time + sec)
     puts "Snooze #{sec/60}min to #{@notify_at}"
     puts "Event: #{to_hash}"
     mark_as_changed
  end

  # returns true if event should be repeated (repeat is defined)
  def should_repeat
    return true if @repeat.length>0
  end

  # plan next repeat
  def do_repeat
    rep = @conv.parse_repeat_time_str(@repeat)
    puts "do_repeat:#{@repeat} what:#{@what} base-when:#{@when} rep:#{rep}"
    if rep[:unit] == 'day'
      time = @conv.get_sec_from_str(@when)
      time = time + rep[:value] * 60*60*24
      @when = @conv.get_str_from_sec(time)
    elsif rep[:unit] == 'month'
      m = /(....)-(..)-(..) (..):(..)/.match(@when)
      throw "Unexpected date format #{@when}" if m.nil?
      d = []
      for i in 1..5
        d[i] = m[i].to_i
      end
      d[2] += rep[:value].to_i
      if d[2] > 12 # handle year overflow
        d[1] += 1
        d[2] -= 12
      end
      @when = sprintf "%04d-%02d-%02d %02d:%02d", d[1],d[2],d[3],d[4],d[5]
    end
    @notify_at = @when
    if @notify_before.length>0
      time = @conv.get_sec_from_str(@when)
      @notify_at = @conv.get_str_from_sec(time - @conv.parse_rel_time_str(@notify_before))
    end
    puts "Repeat at #{@when} notify #{@notify_at}"
    mark_as_changed
  end

  # mark this event as complete
  def do_mark_as_complete(current_time)
     current_time = @conv.get_now_sec if current_time==0
     @completed = 1
     mark_as_changed
  end

  # mark for save (e.g. after each change)
  def mark_as_changed
    @changed=true
  end
end

# ---------------------------------------------------------
# all events
# works in mixed units
# ---------------------------------------------------------
class Events
  attr_accessor :source_file,:target_file,:reference_time,:notification_is_shown,:event_beeing_notified,:verbose,:remaining_items_2b_notified

  def initialize
    @verbose=0
    puts "Events.initialize" if @verbose>0
    @source_file = 'events.yaml'
    @target_file = @source_file
    @conv = TimeConversions.new
    @events = []
    @reference_time=@conv.get_now_sec
    @event_beeing_notified
		@remaining_items_2b_notified
    @notification_is_shown=false  # if true - checking of events is stopped because structure can be changed by notification action (e.g. snooze)
    @last_source_file_time_loaded=0
  end

  def open_notification
    @notification_is_shown=true
  end

  def close_notification
    update_event_after_change
    @notification_is_shown=false
  end

  def update_event_after_change
    return if !@event_beeing_notified.changed
    @events[@event_beeing_notified.index] = @event_beeing_notified.to_hash
    save
  end

  # add new event based on events
  def add_from_edits(edits)
    #puts "add_from_edits event what:#{edits['what'].text} when:#{edits['when'].text}";
    params = Hash.new
    edits.keys.each do |key|
      params[key] = edits[key].text
    end
    result = add_from_params(params)
    puts "add_from_params returned: #{result}" if @verbose>0
    if result
      # show error
      edits[result].focus()
      return
    end
    return 1
  end

  # add new event based on parameters (par['when'])
  # return nil if OK
  # return name of parameter that is incorrect
  def add_from_params(par)
    event = Event.new
    puts "add_from_params event what:#{par}";
    return 'what' if par['what'].length<1
    event.what = par['what'];

    event.description = par['description'] if par['description'] and par['description'].length>0

    time_str = par['when']
    return 'when' if time_str.nil? or time_str.length<1
    # parse when // "([after] <15min|1hour|2days|1mon>|<2018-02-05 [16:18]>)"
    time_when = @conv.parse_rel_time_str(time_str)
    if time_when
      # use relative
      event.when = @conv.get_str_from_sec(time_when + @conv.get_now_sec)
    else
      # try to get absolute time
      time_when = @conv.get_sec_from_str(time_str)
      return 'when' if !time_when;
      event.when = @conv.get_str_from_sec(time_when)
    end

    # parse notify time "(30min, 2day, 1mon, 1hour [before])"
    notify = par['notify']
    if notify and notify.length>0
      event.notify_before = notify
      time_notify = @conv.parse_rel_time_str(notify)
      #puts "add_from_params parsing notify #{notify} parsed to #{time_notify}"
      return 'notify' if !time_notify
      event.notify_at = @conv.get_str_from_sec(@conv.get_sec_from_str(event.when) - time_notify)
    else
      event.notify_at = event.when
    end

    # parse repeat "([every] 2day, 2week, 1mon, 2year)"
    repeat = par['repeat']
    if repeat and repeat.length>0
      time_repeat = @conv.parse_repeat_time_str(repeat)
      return 'repeat' if !time_repeat
      event.repeat = repeat
    end

    if @events
      @events.insert(0,event.to_hash)
    else
      @events = event.to_hash
    end
    save
    nil
  end # add_from_params

  # load all events from storage (YAML) to @events
  def load
    puts "Loading events from file #{@source_file}" if @verbose>0
    File.exists?(@source_file) or throw "Event load failed - file @source_file does not exist"
    @events = YAML.load_file(@source_file);
    @last_source_file_time_loaded = File.mtime(@source_file)
    #puts "Events: #{@events}"
  end

  def is_source_file_changed_after_load
    return @last_source_file_time_loaded != File.mtime(@source_file)
  end

  # save all events stored in @events to storage (YAML)
  def save
    File.open(@target_file, 'w') {|f| f.write @events.to_yaml }
    return
  end

  # immediately check (e.g. used by tests)
  def get_next_event_2b_notified(time_sec)
		e = get_all_events_to_be_notified(time_sec)
		if !e.nil? and e.count
			@event_beeing_notified = e[0]
			return @event_beeing_notified
		end
	end

	def get_all_events_to_be_notified(time_sec)
    return if @notification_is_shown
    if is_source_file_changed_after_load
      load # reload
    end
		notif_events = []
    time_str = @conv.get_str_from_sec(time_sec)
    puts "CheckEvents '#{time_str}'" if @verbose>0
    @events.each_with_index do |ey,index|
      event = Event.new
      event.from_hash(ey,index)
      next if event.completed == 1 # skip completed events
      puts "Checking event '#{event.what}' '#{event.notify_at}'" if @verbose>0
      if time_str >= event.notify_at
        puts "Event '#{event.what}' should be notified now." if @verbose>0
				notif_events.push(event)
      end
    end # @events.each
		@remaining_items_2b_notified = notif_events.count
		return notif_events
    nil
  end

  # check what event is next in range
  def what_is_next(time_sec,range_sec)
    if is_source_file_changed_after_load
      load # reload
    end
    time_from_str = @conv.get_str_from_sec(time_sec)
    time_to_str = @conv.get_str_from_sec(range_sec)
    @event_beeing_notified=nil
    @events.each_with_index do |ey,index|
      event = Event.new
      event.from_hash(ey,index)
      next if event.completed == 1 # skip completed events
      next if !(event.notify_at > time_from_str and event.notify_at < time_to_str)
      #puts "Checking what_is_next '#{event.what}' '#{event.notify_at}' max:'#{time_to_str}'" if @verbose>0
      if @event_beeing_notified.nil?
				# set first event as beeing notified
        @event_beeing_notified = event
      else
        if event.notify_at < @event_beeing_notified.notify_at
          @event_beeing_notified = event
        end
      end
    end # @events.each
    if @event_beeing_notified
      #puts "Event '#{next_event.what}' will be next." if @verbose>0
      return @event_beeing_notified
    end
    nil
  end


end
