class Standard
  # @!group CoilCoolingDXTwoSpeed

  # Prototype CoilCoolingDXTwoSpeed object
  # Enters in default curves for coil by type of coil
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param schedule [String] name of the availability schedule, or [Schedule] Schedule object, or nil in which case default to always on
  # @param type [String] the type of two speed DX coil to reference the correct curve set
  def create_coil_cooling_dx_two_speed(model, name: "2spd DX Clg Coil", schedule: nil, type: nil)

    clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model)

    # set coil name
    clg_coil.setName(name)

    # set coil availability schedule
    coil_availability_schedule = nil
    if schedule.nil?
      # default always on
      coil_availability_schedule = model.alwaysOnDiscreteSchedule
    elsif schedule.class == String
      coil_availability_schedule = model_add_schedule(model, schedule)

      if coil_availability_schedule.nil? && schedule == "alwaysOffDiscreteSchedule"
        coil_availability_schedule = model.alwaysOffDiscreteSchedule
      elsif coil_availability_schedule.nil?
        coil_availability_schedule = model.alwaysOnDiscreteSchedule
      end
    elsif !schedule.to_Schedule.empty?
      coil_availability_schedule = schedule
    else
      coil_availability_schedule = model.alwaysOnDiscreteSchedule
    end
    clg_coil.setAvailabilitySchedule(coil_availability_schedule)

    clg_cap_f_of_temp = nil?
    clg_cap_f_of_flow = nil?
    clg_energy_input_ratio_f_of_temp = nil?
    clg_energy_input_ratio_f_of_flow = nil?
    clg_part_load_ratio = nil?
    clg_cap_f_of_temp_low_spd = nil?
    clg_energy_input_ratio_f_of_temp_low_spd = nil?

    # curve sets
    if type == 'OS default'

      # use OS defaults

    else # default curve set, type == 'PSZ-AC' || 'Split AC' || 'PTAC'

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
      clg_cap_f_of_temp.setCoefficient2x(0.04426)
      clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
      clg_cap_f_of_temp.setCoefficient4y(0.00333)
      clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
      clg_cap_f_of_temp.setMinimumValueofx(17.0)
      clg_cap_f_of_temp.setMaximumValueofx(22.0)
      clg_cap_f_of_temp.setMinimumValueofy(13.0)
      clg_cap_f_of_temp.setMaximumValueofy(46.0)

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
      clg_cap_f_of_flow.setCoefficient2x(0.34053)
      clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
      clg_cap_f_of_flow.setMinimumValueofx(0.75918)
      clg_cap_f_of_flow.setMaximumValueofx(1.13877)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
      clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
      clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
      clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
      clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
      clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
      clg_part_load_ratio.setCoefficient1Constant(0.77100)
      clg_part_load_ratio.setCoefficient2x(0.22900)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
      clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
      clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
      clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
      clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
      clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
      clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
      clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
      clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
      clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

      clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
      clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
      clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
      clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
      clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

      clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
      clg_coil.setBasinHeaterCapacity(10)
      clg_coil.setBasinHeaterSetpointTemperature(2.0)
    end

    clg_coil.setTotalCoolingCapacityFunctionOfTemperatureCurve(clg_cap_f_of_temp) if !clg_cap_f_of_temp.nil?
    clg_coil.setTotalCoolingCapacityFunctionOfFlowFractionCurve(clg_cap_f_of_flow) if !clg_cap_f_of_flow.nil?
    clg_coil.setEnergyInputRatioFunctionOfTemperatureCurve(clg_energy_input_ratio_f_of_temp) if !clg_energy_input_ratio_f_of_temp.nil?
    clg_coil.setEnergyInputRatioFunctionOfFlowFractionCurve(clg_energy_input_ratio_f_of_flow) if !clg_energy_input_ratio_f_of_flow.nil?
    clg_coil.setPartLoadFractionCorrelationCurve(clg_part_load_ratio) if !clg_part_load_ratio.nil?
    clg_coil.setLowSpeedTotalCoolingCapacityFunctionOfTemperatureCurve(clg_cap_f_of_temp_low_spd) if !clg_cap_f_of_temp_low_spd.nil?
    clg_coil.setLowSpeedEnergyInputRatioFunctionOfTemperatureCurve(clg_energy_input_ratio_f_of_temp_low_spd) if !clg_energy_input_ratio_f_of_temp_low_spd.nil?

    return clg_coil
  end
end