require_relative '../lib/events'

puts '---------------------------------------'
puts "Testing time conversions"
c = TimeConversions.new
t=c.parse_rel_time_str('')
!t or throw "error time can't be parsed from zero"
t=c.parse_rel_time_str('3incorrect units')
!t or throw "error time can't be parsed from 3incorrect units"
t=c.parse_rel_time_str('after 5min')
t==60*5 or throw "error parsed relative time:#{t} (expected 5 mins)"
t=c.parse_rel_time_str('2days')
t==60*60*24*2 or throw "error parsed relative time:#{t} (expected 2 days)"
t=c.parse_rel_time_str('after 3weeks')
t==60*60*24*7*3 or throw "error parsed relative time:#{t} (expected 3 weeks)"
t=c.parse_rel_time_str('after 2months')
t==60*60*24*30*2 or throw "error parsed relative time:#{t} (expected 2 months)"

t=c.parse_repeat_time_str('')
!t or throw "error time can't be parsed from zero"
t=c.parse_repeat_time_str('every 2days')
t or throw "error time expected from 'every 2days'"
t[:unit] or throw "error getting units #{t}"
t[:unit]=='day' or throw "error parsing unit from 'every 2 days'"
t[:value]==2 or throw "error parsing value from 'every 2 days'"
t=c.parse_repeat_time_str('3w')
t[:unit]=='day' or throw "error parsing unit from '3w'"
t[:value]==3*7 or throw "error parsing value from '3w'"
t=c.parse_repeat_time_str('2mon')
t[:unit]=='month' or throw "error parsing unit from '2mon'"
t[:value]==2 or throw "error parsing value from '2mon'"

t=c.get_sec_from_str('')
!t or throw "error time can't be parsed from zero"
t=c.get_sec_from_str('2018-01-31')
t or throw "error time can't be parsed from some"

puts "Reverse parse test"
tested_time = c.get_now_sec
tested_time_s = c.get_str_from_sec(tested_time)
puts "Current time: #{tested_time_s} from sec #{tested_time}"
tested_time2 = c.get_sec_from_str(tested_time_s)
tested_time_s2 = c.get_str_from_sec(tested_time2)
tested_time_s == tested_time_s2 or throw "Error tested sec:#{tested_time_s} != #{tested_time_s2}"

puts '---------------------------------------'
puts "Testing events"

es = Events.new
es.verbose = 2
es.target_file='temp/testing_output.yaml'
p={}
p['what']=''
r = es.add_from_params(p)
r == 'what' or throw

p['what']='Testing event'
r = es.add_from_params(p)
r == 'when' or throw

p['when']='after 1week'
r = es.add_from_params(p)
!r or throw "unexpected result:#{r}"

p['notify']='1qq'
r = es.add_from_params(p)
r == 'notify' or throw "unexpected result:#{r}"

p['notify']='1h'
r = es.add_from_params(p)
!r or throw "unexpected result:#{r}"

p['repeat']='2w'
r = es.add_from_params(p)
!r or throw "unexpected result:#{r}"

puts '---------------------------------------'
puts "Testing events notification triggering using artifical time used in .get_next_event_2b_notified(time)"

es = Events.new
es.verbose = 2
es.source_file='temp/testing_output_B.yaml' # make clean file, independent of previous
es.target_file=es.source_file
es.save
time_sec = c.get_now_sec
!es.get_next_event_2b_notified(time_sec) or throw "some notification on empty list"

p={}
event_1_name = 'Event 1'
base_time = c.get_now_sec
p['what']=event_1_name
p['when']='after 2hours'
event_1_when = base_time + 60*60*2
p['notify']='1hour before'
event_1_notify = event_1_when - 60*60*1
es.reference_time = base_time
p['repeat']='every 2weeks'
event_1_description='event1desctiption'
p['description']=event_1_description
r = es.add_from_params(p)
event_2_name = 'Event 2'
p['what']=event_2_name
p['when']='in 2months'
p['notify']='1hour before'
p['repeat']='every 2months'
event_2_description='line1\nline2 and \nline3'
p['description']=event_2_description
event_2_notify = c.get_now_sec + 60*60*24*62
r = es.add_from_params(p)
!r or throw "unexpected result:#{r}"
time_tol = 100 # time tollerance (some data are rounded to minutes)
!es.get_next_event_2b_notified(base_time) or throw "some notification, but not expected"
!es.get_next_event_2b_notified(event_1_notify-time_tol) or throw "some notification, but not expected"
e = es.get_next_event_2b_notified(event_1_notify+time_tol) or throw "no notification, but expected"
e.what == event_1_name or throw "unexpected event notified"
puts '------ checking the snooze function'
e.do_snooze(60*60*2,event_1_notify) # two hours
es.update_event_after_change
event_1_notify += 60*60*2 # add snooze period
!es.get_next_event_2b_notified(event_1_notify-time_tol) or throw "some notification, but not expected"
e = es.get_next_event_2b_notified(event_1_notify+time_tol) or throw "no notification, but expected"
e.what == event_1_name or throw "unexpected event notified"
puts '------- checking the repeat function'
e.do_repeat
es.update_event_after_change
event_1_when += 60*60*24*7*2 - 60*60 # two weeks one hour before
!es.get_next_event_2b_notified(event_1_when-time_tol) or throw "some notification, but not expected"
e = es.get_next_event_2b_notified(event_1_when+time_tol) or throw "no notification, but expected"
e.do_mark_as_complete(event_1_when)
es.update_event_after_change
!es.get_next_event_2b_notified(event_1_when+time_tol) or throw "some notification, but not expected"

puts '---------------------------------------'
puts "Testing events save/load"
es.save
es2 = Events.new
es2.source_file='temp/testing_output_B.yaml'
es2.target_file=es.source_file
es2.load
e = es2.get_next_event_2b_notified(event_2_notify+time_tol)
e or throw "no notification, but expected"
e.what == event_2_name or throw "unexpected event '#{e.what}' notified"
e.description == event_2_description or throw "unexpected description '#{e.description}'"
e.do_repeat

puts "All tests OK"
