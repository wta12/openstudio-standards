class CBES < Standard
  # @!group Space

  # Baseline infiltration rate
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2 exterior above grade envelope area at 75 Pa
  def space_infiltration_rate_75_pa(space)
    basic_infil_rate_cfm_per_ft2 = 1.8
    return basic_infil_rate_cfm_per_ft2
  end
end
