#start the measure
class AddSimplePvToShadingSurfacesByType < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see
  def name
    return "Add Simple PV to Specified Shading Surfaces"
  end

  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for shading surfaces
    chs = OpenStudio::StringVector.new
    chs << "Site Shading"
    chs << "Building Shading"
    chs << "Space/Zone Shading"
    shading_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("shading_type",chs,true)
    shading_type.setDisplayName("Choose the Type of Shading Surfaces to add PV to")
    shading_type.setDefaultValue("Building Shading")
    args << shading_type

    # Fraction of surfaces to contain PV
    fraction_surfacearea_with_pv = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fraction_surfacearea_with_pv",true)
    fraction_surfacearea_with_pv.setDisplayName("Fraction of Included Surface Area with PV")
    fraction_surfacearea_with_pv.setDefaultValue(0.5)
    args << fraction_surfacearea_with_pv

    # Value for Cell Efficiency
    value_for_cell_efficiency = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("value_for_cell_efficiency",true)
    value_for_cell_efficiency.setDisplayName("Fractional Value for Cell Efficiency")
    value_for_cell_efficiency.setDefaultValue(0.12)
    args << value_for_cell_efficiency

    #make an argument for material and installation cost
    material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost",true)
    material_cost.setDisplayName("Material and Installation Costs for the PV ($).")
    material_cost.setDefaultValue(0.0)
    args << material_cost

    #make an argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",true)
    expected_life.setDisplayName("Expected Life (whole years).")
    expected_life.setDefaultValue(20)
    args << expected_life

    #make an argument for o&m cost
    om_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost",true)
    om_cost.setDisplayName("O & M Costs for the PV ($).")
    om_cost.setDefaultValue(0.0)
    args << om_cost

    #make an argument for o&m frequency
    om_frequency = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("om_frequency",true)
    om_frequency.setDisplayName("O & M Frequency (whole years).")
    om_frequency.setDefaultValue(1)
    args << om_frequency

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    #assign the user inputs to variables
    shading_type = runner.getStringArgumentValue("shading_type",user_arguments)
    fraction_surfacearea_with_pv = runner.getDoubleArgumentValue("fraction_surfacearea_with_pv",user_arguments)
    value_for_cell_efficiency = runner.getDoubleArgumentValue("value_for_cell_efficiency",user_arguments)
    material_cost = runner.getDoubleArgumentValue("material_cost",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost = runner.getDoubleArgumentValue("om_cost",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

    #set flags to use later
    costs_requested = false

    #check the surface type for reasonableness
    if shading_type == "Site Shading"
      pv_shading_surfaces = workspace.getObjectsByType("Shading:Site:Detailed".to_IddObjectType)
    elsif shading_type == "Building Shading"
      pv_shading_surfaces = workspace.getObjectsByType("Shading:Building:Detailed".to_IddObjectType)
    elsif shading_type == "Space/Zone Shading"
      pv_shading_surfaces = workspace.getObjectsByType("Shading:Zone:Detailed".to_IddObjectType)
    else
      runner.registerError("You shouldn't see this, something went wrong with choice arguments.")
      return false
    end

    if pv_shading_surfaces.size == 0
      runner.registerAsNotApplicable("The model does not contain any #{shading_type} surfaces. The model will not be altered.")
      return true
    end

    if 0 > fraction_surfacearea_with_pv or fraction_surfacearea_with_pv > 1
      runner.registerError("Please pick a value between or equal to 0 and 1 for the fraction of surface to receive PV.")
      return false
    end

    if 0 > value_for_cell_efficiency or value_for_cell_efficiency > 1
      runner.registerError("Please pick a value between or equal to 0 and 1 for the PV cell efficiency.")
      return false
    end

    #check costs for reasonableness
    if material_cost.abs + om_cost.abs == 0
      runner.registerInfo("No costs were requested for the PV.")
    else
      costs_requested = true
    end

    #check lifecycle arguments for reasonableness
    if not expected_life >= 1 and not expected_life <= 100
      runner.registerError("Choose an integer greater than 0 and less than or equal to 100 for Expected Life.")
    end
    if not om_frequency >= 1
      runner.registerError("Choose an integer greater than 0 for O & M Frequency.")
    end

    #short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
    def neat_numbers(number, roundto = 2) #round to 0 or 2)
      if roundto == 2
        number = sprintf "%.2f", number
      else
        number = number.round
      end
      #regex to add commas
      number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
    end #end def neat_numbers

    #reporting initial condition of model
    gen_pv = workspace.getObjectsByType("Generator:Photovoltaic".to_IddObjectType)
    runner.registerInitialCondition("The initial building had #{gen_pv.size} PV generator objects.")

    #cancel out of model appears to already have PV. current script doesn't handle this, but could be added later
    if gen_pv.size > 0
      runner.registerError("This model appears to already have some PV objects. The measure isn't designed to work on models that already have PV.")
      return false
    end

    # array to hold new IDF objects needed for PV
    string_objects = []

    # add PhotovoltaicPerformance:Simple object
    string_objects << "
      PhotovoltaicPerformance:Simple,
        pvPerformanceObject,  !- Name
        #{fraction_surfacearea_with_pv},  !- Fraction of Surface Area with Active Solar Cells {dimensionless}
        Fixed,                            !- Conversion Efficiency Input Mode
        #{value_for_cell_efficiency};     !- Value for Cell Efficiency if Fixed
        "

    # add Generator:Photovoltaic objects

    # array to hold names of generators for ElectricLoadCenter:Generators object
    generator_list = []

    pv_shading_surfaces.each do |shading_surface|

      #set the fields to the values you want
      surface_name = shading_surface.getString(0).to_s
      gen_name = "gen #{surface_name}".to_s

      # add name to generator list array
      generator_list << gen_name

      # make Generator:Photovoltaic object
      string_objects << "
        Generator:Photovoltaic,
          #{gen_name},                     !- Name
          #{surface_name},                 !- Surface Name ** change to match your surface
          PhotovoltaicPerformance:Simple,  !- Photovoltaic Performance Object Type
          pvPerformanceObject,             !- Module Performance Name
          Decoupled,                       !- Heat Transfer Integration Mode
          1.0,                             !- Number of Modules in Parallel {dimensionless}
          1.0;                             !- Number of Modules in Series {dimensionless}
          "

    end #end of shading surfaces each do

    if generator_list.size == 0
      # put in a failure here if generator_list.size = 0
      exit
    end

    # add pv Always On Schedule
    string_objects << "
    Schedule:Compact,
    pv_script always On,     !- Name
    Fraction,                !- Schedule Type Limits Name
    Through: 12/31,          !- Field 1
    For: AllDays,            !- Field 2
    Until: 24:00,1.0;        !- Field 3
    "

    # add ElectricLoadCenter objects
    build_elec_load_ctr_gen = []

    # start of build_elec_load_ctr_gen string
    build_elec_load_ctr_gen << "
      ElectricLoadCenter:Generators,
        PV list,                 !- Name
        "

    # middle of build_elec_load_ctr_gen string
    if generator_list.size > 1
      for generator in generator_list[0...-1]
        build_elec_load_ctr_gen << "
            #{generator},            !- Generator Name
            Generator:Photovoltaic,  !- Generator Object Type
            20000,                   !- Generator Rated Electric Power Output
            pv_script always On,     !- Generator Availability Schedule Name
            ,                        !- Generator Rated Thermal to Electrical Power Ratio
            "
      end
    end

    # last object special for ; vs , of build_elec_load_ctr_gen string
    build_elec_load_ctr_gen << "
        #{generator_list.reverse[0]},    !- Generator Name
        Generator:Photovoltaic,  !- Generator Object Type
        20000,                   !- Generator Rated Electric Power Output
        pv_script always On,     !- Generator Availability Schedule Name
        ;                        !- Generator Rated Thermal to Electrical Power Ratio
        "

    # merging the ElectricLoadCenter:Generators object into a single string
    string_objects << build_elec_load_ctr_gen.join("")

    string_objects << "
      ElectricLoadCenter:Inverter:Simple,
        Simple Ideal Inverter,   !- Name
        pv_script always On,               !- Availability Schedule Name
        ,                        !- Zone Name
        0.0,                     !- Radiative Fraction
        0.95;                     !- Inverter Efficiency
        "


    string_objects << "
      ElectricLoadCenter:Distribution,
        Simple Electric Load Center,  !- Name
        PV list,                 !- Generator List Name
        Baseload,                !- Generator Operation Scheme Type
        0,                       !- Demand Limit Scheme Purchased Electric Demand Limit {W}
        ,                        !- Track Schedule Name Scheme Schedule Name
        ,                        !- Track Meter Scheme Meter Name
        DirectCurrentWithInverter,  !- Electrical Buss Type
        Simple Ideal Inverter;   !- Inverter Object Name
        "

    # add PV related variable requests
    string_objects << "Output:Variable,*,PV Generator DC Power,hourly;"
    string_objects << "Output:Variable,*,PV Generator DC Energy,hourly;"
    string_objects << "Output:Variable,*,Inverter AC Energy Output,hourly;"
    string_objects << "Output:Variable,*,Inverter AC Power Output,hourly;"
    string_objects << "Output:Variable,*,PV Array Efficiency,hourly;"
    string_objects << "Output:Meter,Photovoltaic:ElectricityProduced,hourly;"

    # add all of the strings to workspace
    # this script won't behave well if added multiple times in the workflow. Need to address name conflicts
    string_objects.each do |string_object|

      idfObject = OpenStudio::IdfObject::load(string_object)
      object = idfObject.get
      wsObject = workspace.addObject(object)

    end

    if costs_requested

      #add mat cost
      lcc_mat_string = "
      LifeCycleCost:RecurringCosts,
        LCC_Mat - #{shading_type} PV,           !- Name
        Replacement,                            !- Category
        #{material_cost},                       !- Cost
        ServicePeriod,                          !- Start of Costs
        0,                                      !- Years from Start
        ,                                       !- Months from Start
        #{expected_life};                       !- Repeat Period Years
        "
      idfObject = OpenStudio::IdfObject::load(lcc_mat_string)
      object = idfObject.get
      wsObject = workspace.addObject(object)
      lcc_mat = wsObject.get

      runner.registerInfo("Added construction cost of $#{neat_numbers(material_cost,0)}, with an expected life of #{lcc_mat.getString(6)} years.")

      #add o&m cost
      lcc_om_string = "
      LifeCycleCost:RecurringCosts,
        LCC_Mat - #{shading_type} PV,           !- Name
        Replacement,                            !- Category
        #{om_cost},                       !- Cost
        ServicePeriod,                          !- Start of Costs
        0,                                      !- Years from Start
        ,                                       !- Months from Start
        #{om_frequency};                       !- Repeat Period Years
        "
      idfObject = OpenStudio::IdfObject::load(lcc_om_string)
      object = idfObject.get
      wsObject = workspace.addObject(object)
      lcc_om = wsObject.get

      runner.registerInfo("Added O & M cost of $#{neat_numbers(om_cost,0)}, at a frequency of #{lcc_om.getString(6)} year(s).")

    end #end of if costs_requested

    #reporting final condition of model
    final_gen_pv = workspace.getObjectsByType("Generator:Photovoltaic".to_IddObjectType)
    runner.registerFinalCondition("The final building has #{final_gen_pv.size} PV generator objects.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddSimplePvToShadingSurfacesByType.new.registerWithApplication









