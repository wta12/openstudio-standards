class ASHRAE901PRM2019 < ASHRAE901PRM
  # @!group SpaceType

  # Sets the selected internal loads to standards-based or typical values.
  # For each category that is selected get all load instances. Remove all
  # but the first instance if multiple instances.  Add a new instance/definition
  # if no instance exists. Modify the definition for the remaining instance
  # to have the specified values. This method does not alter any
  # loads directly assigned to spaces.  This method skips plenums.
  #
  # @param space_type [OpenStudio::Model::SpaceType] space type object
  # @param set_people [Bool] if true, set the people density.
  #   Also, assign reasonable clothing, air velocity, and work efficiency inputs
  #   to allow reasonable thermal comfort metrics to be calculated.
  # @param set_lights [Bool] if true, set the lighting density, lighting fraction
  #   to return air, fraction radiant, and fraction visible.
  # @param set_electric_equipment [Bool] if true, set the electric equipment density
  # @param set_gas_equipment [Bool] if true, set the gas equipment density
  # @param set_ventilation [Bool] if true, set the ventilation rates (per-person and per-area)
  # @param set_infiltration [Bool] if true, set the infiltration rates
  # @return [Bool] returns true if successful, false if not
  def space_type_apply_internal_loads(space_type, set_people, set_lights, set_electric_equipment, set_gas_equipment, set_ventilation, set_infiltration)
    # Skip plenums
    # Check if the space type name
    # contains the word plenum.
    if space_type.name.get.to_s.downcase.include?('plenum')
      return false
    end

    if space_type.standardsSpaceType.is_initialized
      if space_type.standardsSpaceType.get.downcase.include?('plenum')
        return false
      end
    end

    # Pre-process the light instances in the space type
    # Remove all instances but leave one in the space type
    instances = space_type.lights.sort
    if instances.size.zero?
      definition = OpenStudio::Model::LightsDefinition.new(space_type.model)
      definition.setName("#{space_type.name} Lights Definition")
      instance = OpenStudio::Model::Lights.new(definition)
      instance.setName("#{space_type.name} Lights")
      instance.setSpaceType(space_type)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no lights, one has been created.")
      instances << instance
    elsif instances.size > 1
      instances.each_with_index do |inst, i|
        next if i.zero?

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
        inst.remove
      end
    end

    # Get userdata from userdata_space and userdata_spacetype
    user_spaces = @standards_data.key?('userdata_space') ? @standards_data['userdata_space'] : nil
    user_spacetypes = @standards_data.key?('userdata_spacetype') ? @standards_data['userdata_spacetype'] : nil
    if user_spaces && user_spaces.length >= 1 && has_user_lpd_values(user_spaces)
      # if space type has user data & data has lighting data for user space
      # call this function to enforce space-space_type one on one relationship
      space_to_space_type_apply_lighting(user_spaces, user_spacetypes, space_type)
    else
      if user_spacetypes && user_spacetypes.length >= 1 && has_user_lpd_values(user_spacetypes)
        # if space type has user data & data has lighting data for user space type
        user_space_type_index = user_spacetypes.index { |user_spacetype| user_spacetype['name'] == space_type.name.get }
        if user_space_type_index.nil?
          # cannot find a matched user_spacetype to space_type, use space_type to set LPD
          set_lpd_on_space_type(space_type, user_spaces, user_spacetypes)
        else
          user_space_type = user_spacetypes[user_space_type_index]
          # If multiple LPD value exist - then enforce space-space_type one on one relationship
          if has_multi_lpd_values_user_data(user_space_type, space_type)
            space_to_space_type_apply_lighting(user_spaces, user_spacetypes, space_type)
          else
            # Process the user_space type data - at this point, we are sure there is no lighting per length
            # So all the LPD should be identical by space
            # Loop because we need to assign the occupancy control credit to each space for
            # Schedule processing.
            space_type_lighting_per_area = 0.0
            space_type.spaces.each do |space|
              space_lighting_per_area = calculate_lpd_from_userdata(user_space_type, space)
              space_type_lighting_per_area = space_lighting_per_area
            end
            space_type.lights[0].lightsDefinition.setWattsperSpaceFloorArea(OpenStudio.convert(space_type_lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          end
        end
      else
        # no user data, set space_type LPD
        set_lpd_on_space_type(space_type, user_spaces, user_spacetypes)
      end
    end
  end

  # Function to tset LPD on default space type
  def set_lpd_on_space_type(space_type, user_spaces, user_spacetypes)
    if has_multi_lpd_values_space_type(space_type)
      # If multiple LPD value exist - then enforce space-space_type one on one relationship
      space_to_space_type_apply_lighting(user_spaces, user_spacetypes, space_type)
    else
      # use default - loop through space to assign occupancy credit to each space.
      space_type_lighting_per_area = 0.0
      space_type.spaces.each do |space|
        space_lighting_per_area = calculate_lpd_by_space(space_type, space)
        space_type_lighting_per_area = space_lighting_per_area
      end
      space_type.lights[0].lightsDefinition.setWattsperSpaceFloorArea(OpenStudio.convert(space_type_lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
    end
  end

  # Function that applies user LPD to each space by duplicating space types
  # This function is used when there are user space data available or
  # the spaces under space type has lighting per length value which may cause multiple
  # lighting power densities under one space_type.
  # @param user_spaces hash data contained in the user space
  # @param user_spacetypes hash data contained in the user spacetypes
  # @param space_type OpenStudio::Model::SpaceType object
  def space_to_space_type_apply_lighting(user_spaces, user_spacetypes, space_type)
    space_lighting_per_area_hash = {}
    # first priority - user_space data
    if user_spaces && user_spaces.length >= 1
      space_type.spaces.each do |space|
        user_space_index = user_spaces.index { |user_space| user_space['name'] == space.name.get }
        unless user_space_index.nil?
          user_space_data = user_spaces[user_space_index]
          if user_space_data.key?('num_std_ltg_types') && user_space_data['num_std_ltg_types'].to_f > 0
            space_lighting_per_area = calculate_lpd_from_userdata(user_space_data, space)
            space_lighting_per_area_hash[space.name.get] = space_lighting_per_area
          end
        end
      end
    end
    # second priority - user_spacetype
    if user_spacetypes && user_spacetypes.length >= 1
      # if space type has user data
      user_space_type_index = user_spacetypes.index { |user_spacetype| user_spacetype['name'] == space_type.name.get }
      unless user_space_type_index.nil?
        user_space_type_data = user_spacetypes[user_space_type_index]
        if user_space_type_data.key?('num_std_ltg_types') && user_space_type_data['num_std_ltg_types'].to_f > 0
          space_type.spaces.each do |space|
            # unless the space is in the hash, we will add lighting per area to the space
            space_name = space.name.get
            unless space_lighting_per_area_hash.key?(space_name)
              space_lighting_per_area = calculate_lpd_from_userdata(user_space_type_data, space)
              space_lighting_per_area_hash[space_name] = space_lighting_per_area
            end
          end
        end
      end
    end
    # Third priority
    # set space type to every space in the space_type, third priority
    # will also be assigned from the default space type
    space_type.spaces.each do |space|
      space_name = space.name.get
      unless space_lighting_per_area_hash.key?(space_name)
        space_lighting_per_area = calculate_lpd_by_space(space_type, space)
        space_lighting_per_area_hash[space_name] = space_lighting_per_area
      end
    end
    # All space is explored.
    # Now rewrite the space type in each space - might need to change the logic
    space_type.spaces.each do |space|
      space_name = space.name.get
      new_space_type = space_type.clone.to_SpaceType.get
      space.setSpaceType(new_space_type)
      lighting_per_area = space_lighting_per_area_hash[space_name]
      new_space_type.lights.each do |inst|
        definition = inst.lightsDefinition
        unless lighting_per_area.zero?
          new_definition = definition.clone.to_LightsDefinition.get
          new_definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          inst.setLightsDefinition(new_definition)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set LPD to #{lighting_per_area} W/ft^2.")
        end
      end
    end
    space_type.remove
  end

  # Modify the lighting schedules for Appendix G PRM for 2016 and later
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  def space_type_light_sch_change(model)
    # set schedule for lighting
    schedule_hash = {}
    model.getSpaces.each do |space|
      unless space.spaceType.get.lights.empty?
        ltg = space.spaceType.get.lights[0]
        if ltg.schedule.is_initialized
          ltg_schedule = ltg.schedule.get
          ltg_schedule_name = ltg_schedule.name
          occupancy_sensor_credit = space.additionalProperties.getFeatureAsDouble('occ_control_credit')
          new_ltg_schedule_name = "#{ltg_schedule_name}_%.4f" % occupancy_sensor_credit
          if schedule_hash.key?(new_ltg_schedule_name)
            # In this case, there is a schedule created, can retrieve the schedule object and reset in this space type
            schedule_rule = schedule_hash[new_ltg_schedule_name]
            ltg.setSchedule(schedule_rule)
          else
            # In this case, create a new schedule
            # 1. Clone the existing schedule
            new_rule_set_schedule = copy_ltg_schedule(ltg_schedule, occupancy_sensor_credit, model)
            if ltg.setSchedule(new_rule_set_schedule)
              schedule_hash[new_ltg_schedule_name] = new_rule_set_schedule
            end
          end
        end
      end
    end
  end

  def copy_ltg_schedule(schedule, adjustment_factor, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ScheduleRuleset', "Creating a new lighting schedule that applies occupancy sensor adjustment factor: #{adjustment_factor} based on #{schedule.name.get} schedule" )
    new_schedule_name = "#{schedule.name.get}_%.4f" % adjustment_factor
    ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    ruleset.setName(new_schedule_name)

    # schedule types limits and default day schedule - keep the copy
    schedule_ruleset = schedule.to_ScheduleRuleset.get
    schedule_type_limit = schedule_ruleset.scheduleTypeLimits.get
    default_day_schedule = schedule_ruleset.defaultDaySchedule
    default_winter_design_day_schedule = schedule_ruleset.winterDesignDaySchedule
    default_summer_design_day_schedule = schedule_ruleset.summerDesignDaySchedule

    schedule_ruleset.scheduleRules.each do |week_rule|
      day_rule = week_rule.daySchedule
      start_date = week_rule.startDate.get
      end_date = week_rule.endDate.get

      # create a new day rule - copy and apply the ajustment factor
      new_day_rule = OpenStudio::Model::ScheduleDay.new(model)
      new_day_rule.setName("#{day_rule.name.get}_%.4f" % adjustment_factor)
      new_day_rule.setScheduleTypeLimits(schedule_type_limit)

      # process day rule
      times = day_rule.times()
      # remove the effect of occupancy sensors
      times.each do |time|
        hour_value = day_rule.getValue(time)
        new_value = hour_value / (1.0 - adjustment_factor.to_f)
        if new_value > 1
          new_day_rule.addValue(time, 1.0)
        else
          new_day_rule.addValue(time, new_value)
        end
      end

      # create week rule schedule
      new_week_rule = OpenStudio::Model::ScheduleRule.new(ruleset, new_day_rule)
      new_week_rule.setName("#{week_rule.name.get}_%.4f" % adjustment_factor)
      new_week_rule.setApplySunday(week_rule.applySunday)
      new_week_rule.setApplyMonday(week_rule.applyMonday)
      new_week_rule.setApplyTuesday(week_rule.applyTuesday)
      new_week_rule.setApplyWednesday(week_rule.applyWednesday)
      new_week_rule.setApplyThursday(week_rule.applyThursday)
      new_week_rule.setApplyFriday(week_rule.applyFriday)
      new_week_rule.setApplySaturday(week_rule.applySaturday)
      new_week_rule.setStartDate(start_date)
      new_week_rule.setEndDate(end_date)
    end
    # default day schedule
    default_day = ruleset.defaultDaySchedule
    default_day.clearValues
    default_day.times.each_index { |counter| default_day.addValue(default_day_schedule.times[counter], default_day_schedule.values[counter]) }
    # winter design day schedule
    winter_design_day_schedule = ruleset.winterDesignDaySchedule
    winter_design_day_schedule.clearValues
    winter_design_day_schedule.times.each_index { |counter| winter_design_day_schedule.addValue(default_winter_design_day_schedule.times[counter], default_winter_design_day_schedule.values[counter]) }
    summer_design_day_schedule = ruleset.summerDesignDaySchedule
    summer_design_day_schedule.clearValues
    summer_design_day_schedule.times.each_index { |counter| summer_design_day_schedule.addValue(default_summer_design_day_schedule.times[counter], default_summer_design_day_schedule.values[counter]) }
    return ruleset
  end

  # calculate the lighting power density per area based on space type
  # The function will calculate the LPD based on the space type (STRING)
  # It considers lighting per area, lighting per length as well as occupancy factors in the database.
  # @param space_type [String]
  # @param space [OpenStudio::Model::Space]
  def calculate_lpd_by_space(space_type, space)
    # get interior lighting data
    space_type_properties = interior_lighting_get_prm_data(space_type)
    space_lighting_per_area = 0.0
    # Assign data
    lights_have_info = false
    lighting_per_area = space_type_properties['w/ft^2'].to_f
    lighting_per_length = space_type_properties['w/ft'].to_f
    manon_or_partauto = space_type_properties['manon_or_partauto'].to_i
    lights_have_info = true unless lighting_per_area.zero? && lighting_per_length.zero?
    occ_control_reduction_factor = 0.0

    if lights_have_info
      # Space height
      space_volume = space.volume
      space_area = space.floorArea
      space_height = OpenStudio.convert(space_volume / space_area, 'm', 'ft').get
      # calculate the new lpd values
      space_lighting_per_area = lighting_per_length * space_height + lighting_per_area

      # Adjust the occupancy control sensor reduction factor from dataset
      if manon_or_partauto == 1
        occ_control_reduction_factor = space_type_properties['occup_sensor_savings'].to_f
      else
        occ_control_reduction_factor = space_type_properties['occup_sensor_auto_on_svgs'].to_f
      end
    end
    # add calculated occupancy control credit for later ltg schedule adjustment
    space.additionalProperties.setFeature('occ_control_credit', occ_control_reduction_factor)
    return space_lighting_per_area
  end

  # Function checks whether the user data contains lighting data
  def has_user_lpd_values(user_space_data)
    user_space_data.each do |user_data|
      if user_data.key?('num_std_ltg_types') && user_data['num_std_ltg_types'].to_f > 0
        return true
      end
    end
    return false
  end

  # Function checks whether there are multi lpd values in the space type
  # multi-lpd value means there are multiple spaces and the lighting_per_length > 0
  def has_multi_lpd_values_space_type(space_type)
    space_type_properties = interior_lighting_get_prm_data(space_type)
    lighting_per_length = space_type_properties['w/ft'].to_f
    return space_type.spaces.size > 1 && lighting_per_length > 0
  end

  # Function checks whether there are multi lpd values in the space type from user's data
  # The sum of each space fraction in the user_data is assumed to be 1.0
  # multi-lpd value means lighting per area > 0 and lighting_per_length > 0
  def has_multi_lpd_values_user_data(user_data, space_type)
    num_std_ltg_types = user_data['num_std_ltg_types'].to_i
    std_ltg_index = 0 # loop index
    # Loop through standard lighting type in a space
    sum_lighting_per_area = 0
    sum_lighting_per_length = 0
    while std_ltg_index < num_std_ltg_types
      # Retrieve data from user_data
      type_key = 'std_ltg_type%02d' % (std_ltg_index + 1)
      sub_space_type = user_data[type_key]
      # Adjust while loop condition factors
      std_ltg_index += 1
      # get interior lighting data
      sub_space_type_properties = interior_lighting_get_prm_data(sub_space_type)
      # Assign data
      lighting_per_length = sub_space_type_properties['w/ft'].to_f
      sum_lighting_per_length += lighting_per_length
    end
    return space_type.spaces.size > 1 && sum_lighting_per_length > 0
  end

  # Calculate the lighting power density per area based on user data (space_based)
  # The function will calculate the LPD based on the space type (STRING)
  # It considers lighting per area, lighting per length as well as occupancy factors in the database.
  # The sum of each space fraction in the user_data is assumed to be 1.0
  # @param user_data [Hash] user data from the user csv
  # @param space [OpenStudio::Model::Space]
  def calculate_lpd_from_userdata(user_data, space)
    num_std_ltg_types = user_data['num_std_ltg_types'].to_i
    space_lighting_per_area = 0.0
    occupancy_control_credit_sum = 0.0
    std_ltg_index = 0 # loop index
    # Loop through standard lighting type in a space
    while std_ltg_index < num_std_ltg_types
      # Retrieve data from user_data
      type_key = 'std_ltg_type%02d' % (std_ltg_index + 1)
      frac_key = 'std_ltg_type_frac%02d' % (std_ltg_index + 1)
      sub_space_type = user_data[type_key]
      sub_space_type_frac = user_data[frac_key].to_f
      # Adjust while loop condition factors
      std_ltg_index += 1
      # get interior lighting data
      sub_space_type_properties = interior_lighting_get_prm_data(sub_space_type)
      # Assign data
      lights_have_info = false
      lighting_per_area = sub_space_type_properties['w/ft^2'].to_f
      lighting_per_length = sub_space_type_properties['w/ft'].to_f
      lights_have_info = true unless lighting_per_area.zero? && lighting_per_length.zero?
      manon_or_partauto = sub_space_type_properties['manon_or_partauto'].to_i

      if lights_have_info
        # Space height
        space_volume = space.volume
        space_area = space.floorArea
        space_height = OpenStudio.convert(space_volume / space_area, 'm', 'ft').get
        # calculate and add new lpd values
        user_space_type_lighting_per_area = (lighting_per_length * space_height +
          lighting_per_area) * sub_space_type_frac
        space_lighting_per_area += user_space_type_lighting_per_area

        # Adjust the occupancy control sensor reduction factor from dataset
        occ_control_reduction_factor = 0.0
        if manon_or_partauto == 1
          occ_control_reduction_factor = sub_space_type_properties['occup_sensor_savings'].to_f
        else
          occ_control_reduction_factor = sub_space_type_properties['occup_sensor_auto_on_svgs'].to_f
        end
        # Now calculate the occupancy control credit factor (weighted by frac_lpd)
        occupancy_control_credit_sum += occ_control_reduction_factor * user_space_type_lighting_per_area
      end
    end
    # add calculated occupancy control credit for later ltg schedule adjustment
    # If space_lighting_per_area = 0, it means there is no lights_have_info, and subsequently, the occupancy_control_credit_sum should be 0
    space.additionalProperties.setFeature('occ_control_credit', space_lighting_per_area > 0 ? occupancy_control_credit_sum / space_lighting_per_area : occupancy_control_credit_sum)
    return space_lighting_per_area
  end
end
