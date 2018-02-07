require 'date'

class TimeConversions
  # input string (<30min|2day|1mon|1hour>)
  # output time in seconds
  def parse_rel_time_str(str)
    puts "parse_rel_time_str(#{str})"
    m = /[\s]*(\d+)mi|(\d+)h|(\d+)d|(\d+)w|(\d+)mo|(\d+)y/.match(str)
    return if m.nil?
    return 60*m[1].to_i if m[1] # minutes
    return 60*60*m[2].to_i if m[2] # hours
    return 60*60*24*m[3].to_i if m[3] # days
    return 60*60*24*7*m[4].to_i if m[4] # weeks
    return 60*60*24*30*m[5].to_i if m[5] # months
    return 60*60*24*365*m[6].to_i if m[6] # years
  end

  # parse repeat "([every] 2day, 2week, 1month, 2year)"
  # result: :value=>2,:unit=>'day','month','year'
  def parse_repeat_time_str(str)
    puts "parse_repeat_time_str(#{str})"
    m = /[\s]*(\d+)d|(\d+)w|(\d+)mo|(\d+)y/.match(str)
    return if m.nil?
    return {:value=>m[1].to_i,:unit=>'day'} if m[1] # days
    return {:value=>m[2].to_i*7,:unit=>'day'} if m[2] # weeks
    return {:value=>m[3].to_i,:unit=>'month'} if m[3] # months
    return {:value=>m[4].to_i*12,:unit=>'month'} if m[4] # years
  end

  def get_now_sec
    Time.now.to_i
  end

  def get_str_from_sec(sec)
    puts "get_str_from_sec(#{sec})"
    t = Time.at(sec)
    return t.strftime('%Y-%m-%d %H:%M')
  end

  # input: "2011-06-02 [23:59]"
  def get_sec_from_str(str)
    puts "get_sec_from_str(#{str})"
    m = (/(....)-(..)-(..) (..):(..)/.match(str))
    #puts "get_sec_from_str Parsed date/time #{m[1..5]}" if m
    return Time.local(m[1],m[2],m[3],m[4],m[5]).to_i if m
    m = /(....)-(..)-(..)/.match(str)
    #puts "get_sec_from_str Parsed date only #{m}"
    return Time.local(m[1],m[2],m[3]).to_i if m
  end

end
