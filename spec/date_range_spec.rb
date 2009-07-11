require File.dirname(__FILE__) + '/spec_helper'

describe DateRange do
  describe "#parse" do
    it "should parse a simple range" do
      range = DateRange.parse("jan 1 2009 - dec 12 2009")
      range.first.should == Chronic.parse("jan 1 2009", :guess => false).first
      range.last.should == Chronic.parse("dec 12 2009", :guess => false).last
    end
    
    it "should parse a date as a range" do
      range = DateRange.parse("jan 1 2009")
      range.first.should == Chronic.parse("jan 1 2009", :guess => false).first
      range.last.should == Chronic.parse("jan 1 2009", :guess => false).last
    end
    
    it "should parse the second in the context of the first" do
      range = DateRange.parse("jan 1 2009 8am-5pm")
      range.first.should == Chronic.parse("jan 1 2009 8am", :guess => false).first
      range.last.should == Chronic.parse("jan 1 2009 5pm", :guess => false).last
    end
    
    it "should handle odd am/pm" do
      range = DateRange.parse("jan 1 2009 8-11pm")
      range.first.should == Chronic.parse("jan 1 2009 8pm", :guess => false).first
      range.last.should == Chronic.parse("jan 1 2009 11pm", :guess => false).last
    end
    
    it "should return nil on  odd input" do
      DateRange.parse("dsafasdfas").should be_nil
    end
    
    it "should parse this" do
      range = DateRange.parse("thursday from 9 til 5")
      range.first.should == Chronic.parse("this thursday 9am", :guess => false).first
      range.last.should == Chronic.parse("this thursday 5pm", :guess => false).last
    end
    
    it "should parse something chronic can't get" do
      range = DateRange.parse("9/17 8am - 7pm")
      range.first.should == Chronic.parse("9/17/2009 8am", :guess => false).first
      range.last.should == Chronic.parse("9/17/2009 7pm", :guess => false).last      
      
      range = DateRange.parse("jan 1 8am-5pm 2009")
      range.first.should == Chronic.parse("jan 1 2009 8am", :guess => false).first
      range.last.should == Chronic.parse("jan 1 2009 5pm", :guess => false).last
    end
    
    it "should parse dates only" do 
      range = DateRange.parse("9/17-28")
      range.first.should == Chronic.parse("9/17/2009", :guess => false).first
      range.last.should == Chronic.parse("9/28/2009", :guess => false).last      
      
      range = DateRange.parse("Sept 17-28")
      range.first.should == Chronic.parse("9/17/2009", :guess => false).first
      range.last.should == Chronic.parse("9/28/2009", :guess => false).last      
      
      range = DateRange.parse("Sept 17-28 2009")
      range.first.should == Chronic.parse("9/17/2009", :guess => false).first
      range.last.should == Chronic.parse("9/28/2009", :guess => false).last      
      
    end
    
    it "should recognize repeating ranges" do
      range = DateRange.parse("thursdays")
      range.should be_repeating_weekly
    
      range = DateRange.parse("evenings")
      range.should_not be_repeating_weekly
      range.should be_repeating_daily

      range = DateRange.parse("thursday evenings")
      range.should be_repeating_weekly
      range.should_not be_repeating_daily
      # 
      # range = DateRange.parse("weekday evenings")
      # range.should be_repeating_daily
    end
  end
  
  describe "#overlapping" do
    it "should enumerate the repeating ranges between the dates" do
      range = DateRange.parse("thursdays")
      range.should be_repeating_weekly
      range.should_not be_repeating_daily
      bounds = DateRange.parse("7/1/09 - 7/31/09")
      range.overlapping(bounds).should be_a(DateRangeList)
      range.overlapping(bounds).to_s.should == "Jul  2, Jul  9, Jul 16, Jul 23, Jul 30"
      range.overlapping(bounds).should == [
        DateRange.parse("7/2/09"),
        DateRange.parse("7/9/09"),
        DateRange.parse("7/16/09"),
        DateRange.parse("7/23/09"),
        DateRange.parse("7/30/09")
      ]
    end
    
    it "should return a non-repeating range if its within the bounds" do
      range = DateRange.parse("7/10/09")
      bounds = DateRange.parse("7/1/09 - 7/31/09")
      range.overlapping(bounds).should == [range]
    end
  end
  
  describe "#to_s" do
    
    it "should handle same day" do
      DateRange.parse("jan 1 8am-5pm").to_s.should == "Jan  1 8am-5pm"
      DateRange.parse("jan 1 8am-10am").to_s.should == "Jan  1 8-10am"
      DateRange.parse("jan 1 2015 8am-10am").to_s.should == "Jan  1 2015 8-10am"
      DateRange.parse("jan 1 - jan 1").to_s.should == "Jan  1"
    end
    
    it "should handle cross days" do
      DateRange.parse("jan 1 2015 8am - jan 2 10am").to_s.should == "Jan  1 2015 8am - Jan  2 2015 10am"
      DateRange.parse("jan 1 8am - jan 2 10am").to_s.should == "Jan  1 8am - Jan  2 10am"
      DateRange.parse("dec 25 2009 8am - jan 2 2010 10am").to_s.should == "Dec 25 8am - Jan  2 10am"
    end
    
    it "should handle minutes" do
      DateRange.parse("aug 25 8pm - 8:30pm").to_s.should == "Aug 25 8-8:30pm"
    end
    
    it "should handle cross months" do
      DateRange.parse("aug 25 - sept 3").to_s.should == "Aug 25 - Sep  3"
    end
  end
end
