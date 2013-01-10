module Products::SchedulingSupport
  extend ActiveSupport::Concern

  included do
    has_many :schedule_rules
    has_many :reservations, :foreign_key => 'product_id'
  end

  def active_reservations
    self.reservations.active
  end

  def can_purchase? (group_ids = nil)
    if schedule_rules.empty?
      false
    else
      super
    end
  end

  def first_available_hour
    return 0 unless schedule_rules.any?
    schedule_rules.min { |a,b| a.start_hour <=> b.start_hour }.start_hour
  end
  
  def last_available_hour
    return 23 unless schedule_rules.any?
    max_rule = schedule_rules.max { |a,b| hour_floor(a) <=> hour_floor(b) }
    max_rule.end_min == 0 ? max_rule.end_hour - 1 : max_rule.end_hour
  end

  # find the next available reservation based on schedule rules and existing reservations
  def next_available_reservation(after = Time.zone.now, not_a_conflict=nil)
    reservation = nil
    day_of_week = after.wday
    0.upto(6) do |i|
      day_of_week = (day_of_week+i) % 6
      # find rules for day of week, sort by start hour
      rules = self.schedule_rules.select { |r| r.send("on_#{Date::ABBR_DAYNAMES[day_of_week].downcase}".to_sym) }.sort_by{ |r| r.start_hour }
      rules.each do |rule|
        # build rule start and end times
        tstart = Time.zone.local(after.year, after.month, after.day, rule.start_hour, rule.start_min, 0)
        tend   = Time.zone.local(after.year, after.month, after.day, rule.end_hour, rule.end_min, 0)
        # we can't start before tstart
        after  = tstart if after < tstart
        # check for conflicts with rule interval/duration time
        if (after.min % rule.duration_mins.to_i) != 0
          # adjust to next interval
          after += (rule.duration_mins.to_i - (after.min % rule.duration_mins.to_i)).minutes
        end
        while (after < tend)
          duration = self.min_reserve_mins.to_i < 15 ? 15.minutes : self.min_reserve_mins.to_i.minutes
          # build reservation
          reservation = self.reservations.new(:reserve_start_at => after, :reserve_end_at => after+duration)
          # check for conflicts with an existing reservation
          conflict=reservation.conflicting_reservation
          return reservation if conflict.nil? || not_a_conflict == conflict
          # we have a conflict, reset reservation and increment after by the rule's interval/duration time
          reservation = nil
          # after += self.min_reserve_mins.to_i.minutes
          after += duration
        end
      end
      # advance to start of next day
      after = after.end_of_day+1.second
    end
    reservation
  end

  def available_schedule_rules(user)
    if requires_approval?
      self.schedule_rules.available_to_user user
    else
      self.schedule_rules
    end
  end


end