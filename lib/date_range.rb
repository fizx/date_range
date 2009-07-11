require "chronic"
require "active_support"
class DateRangeError < RuntimeError; end

class DateRangeList < Array
  def to_s
    map(&:to_s).join(", ")
  end
end

class DateRange < Range
  NOT_DELIMITER = /\bexcept\b|\bnot\b/i
  DELIMITER = /\-|\buntil\b|\bto\b|\btil\b/i
  IGNORE = /\b(from|between)\b/i
  AMPM = /\d\s*(am|pm)/i
  NUMERIC = /\A\s*\d+\s*\Z/
  ENDS_NUMERIC = /(\s*)(\d+)(\s*)\Z/
  
  WEEK = 604800
  DAY  = 86400
  
  WEEKLYS    = /\b(sunday|monday|tuesday|wednesday|thursday|friday|saturday)s\b/i
  WEEKLYABLE = /\b(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b/i
  WEEKLY     = /\b(every\s*week|weekly)\b/i
  DAILYS     = /\b(morning|afternoon|evening)s\b/i
  DAILYABLE  = /\b(morning|afternoon|evening)\b/i
  DAILY     = /\b(every\s*day|daily)\b/i
  
  def initialize(first, last, options = {})
    super(first, last)
    @options = options
  end
  
  def repeating_weekly?
    @options[:weekly] || (@options[:weeklyable] && @options[:daily])
  end

  def repeating_daily?
    @options[:daily] && !@options[:weeklyable]
  end
  
  def overlapping(range)
    ranges = DateRangeList.new
    
    if repeating_daily? || repeating_weekly?
      interval = repeating_daily? ? DAY : WEEK
      tf = first
      tl = last
      
      until tl < range.first
        tf -= interval
        tl -= interval
      end
      
      while (tf += interval) && (tl += interval) && tf <= range.last
        ranges << DateRange.new(tf, tl)
      end
    else
      if last >= range.first && first <= range.last
        ranges << self
      end
    end
    
    ranges
  end
  
  def self.modifiers(string, options, keys)
    keys.each do |key|
      base    = const_get(key.upcase)
      plural  = const_get(key.upcase + "S")
      able    = const_get(key.upcase + "ABLE")

      if options[:"#{key}"] = (string =~ base) || (string =~ plural)
        string.gsub!(plural, '\1')
        string.gsub!(base, '')
      end
      options[:"#{key}able"] = options[:"#{key}"] || (string =~ able)
    end
  end
  
  def self.parse(string)
    options = {}
    
    string.gsub!(IGNORE, '')
    
    string.gsub!(/([a-z]+)\s+(\d+)\s*\-\s*(\d+)\s+(\d{4})/i, '\1 \2 \4 - \1 \3 \4')

    modifiers(string, options, %w[weekly daily])
    
    # "Sept 17-28 2009" => "Sept 17 2009 - Sept 28 2009"
    string.gsub!(/([a-z]+)\s+(\d+)\s*\-\s*(\d+)\s+(\d{4})/i, '\1 \2 \4 - \1 \3 \4')
    
    # "Sept 17-28" => "Sept 17 - Sept 28"
    string.gsub!(/([a-z]+)\s+(\d+)\s*\-\s*(\d+)/i, '\1 \2 - \1 \3')
    
    # "9/17-28" => "9/17/year - 9/28/year"
    year = Time.now.year
    string.gsub!(/(^|\s)(\d+)\/(\d+)\-(\d+)(\s|$)/, "\\1\\2/\\3/#{year} - \\1\\2/\\4/#{year}\\5")
    
    # "9/17" => "9/17/year"
    string.gsub!(/(^|\s)(\d+)\/(\d+)(\s|$)/, "\\1\\2/\\3/#{year}\\4")
    
    # "jan 1 8am-5pm 2009" => "jan 1 2009 8am - 5pm"
    string.gsub!(/(.*)\b([a-z0-9:]+)\s*-\s*(\d[a-z0-9:]*)\s+(.*)/, "\\1 \\4 \\2 - \\3")
    
    first_string, last_string = string.split(DELIMITER)

    STDERR.puts "preparsed: #{string.split(DELIMITER).inspect}"
    
    if last_string && last_string =~ AMPM && !(first_string =~ AMPM)
      first_string += last_string[AMPM, 1]
    end
    
    first_range = Chronic.parse(first_string, :guess => false)
    first_date = first_range && first_range.first || Time.parse(first_string)
    
    return nil unless first_range
    
    last_date = last_string ? 
                  Chronic.parse(last_string, :guess => false, :now => first_date).last :
                  first_range.last                
    new(first_date, last_date, options)
  end
  
  
  def to_s
    m1 = first.min == 0 ? "" : ":%1M"
    m2 = last.min == 0 ? "" : ":%2M"
    yr1 = first > 2.months.ago && first < 10.months.from_now ? "" : " %1Y"
    yr2 = last > 2.months.ago && last < 10.months.from_now ? "" : " %2Y"
    string = if first.year == last.year
      if first.month == last.month
        if first.day == last.day
          if first.hour / 12 == last.hour / 12
            "%1b %1e#{yr1} %1l#{m1}-%2l#{m2}%2P"
          else
            "%1b %1e#{yr1} %1l#{m1}%1P-%2l#{m2}%2P"
          end
        end
      end
    end
    
    string ||= "%1b %1e#{yr1} %1l#{m1}%1P - %2b %2e#{yr2} %2l#{m2}%2P"
    
    if self.first.hour == 0 && self.first.min == 0 && self.last.hour == 0 && self.last.min == 0
      off = self.last - 1 
      if off.day == self.first.day && off.month == self.first.month && off.year == self.first.year 
        string = string.split(DELIMITER).first
      end
      strftime ignore_time(string), self.first, off
    else
      strftime string
    end
  end
  
  def ignore_time(string)
    string.gsub(/\s*(%\d[PMlI])+\s*/, ' ').strip
  end
  
  def strftime(string, first = self.first, last = self.last)
    return nil unless string
    string = string.gsub("%2", "%%").gsub("%1", "%")
    string = ext_strftime(first, string)
    string = first.strftime(string)
    string = string.gsub("%2", "%")
    string = ext_strftime(last, string)
    last.strftime string
  end
  
  def ext_strftime(time, string)
    p = time.hour / 12 == 0 ? "am" : "pm"
    l = time.hour % 12
    l = 12 if l == 0
    l = l.to_s
    
    string.gsub(/([^%]|^)%l/, "\\1#{l}").gsub(/([^%]|^)%P/, "\\1#{p}")
  end  
end