
class NTimer
  attr_accessor :period_sec;

  def initialize(period_sec)
    set_period(period_sec)
    arm
  end

  def set_period(period_sec)
    @period_sec = period_sec
  end

  def arm
    @next_time = Time.now.to_i + @period_sec
  end

  def set_to_expire
    @next_time = Time.now.to_i
  end

  def expired
    #puts "Timer:Expire: #{@next_time - Time.now.to_i}"
    if Time.now.to_i >= @next_time
      return true
    end
  end

end
