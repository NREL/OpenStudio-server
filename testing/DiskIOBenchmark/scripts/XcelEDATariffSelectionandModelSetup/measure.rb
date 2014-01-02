#see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#Query the user to select Xcel tariffs for consideration (a list of Boolean inputs, one for each tariff) and analysis period length only
#   only going to let people choose 1 electric and 1 gas rate for now 
#TODO	Remove all existing tariffs
#   this is difficult to do in workspace, and not likely necessary.  Skipping for first version
#Add selected Xcel tariffs
#Set timestep to demand window
#TODO	Set economic parameters such as discount rate, etc to hard coded values (current NIST values for 2012)




#start the measure
class XcelEDATariffSelectionandModelSetup < OpenStudio::Ruleset::WorkspaceUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "XcelEDATariffSelectionandModelSetup"
  end
  
  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
 
    #make an argument for the electric tariff
    elec_chs = OpenStudio::StringVector.new
    elec_chs << "Residential General"
    elec_chs << "Commercial"
    elec_chs << "Primary General"
    elec_chs << "Secondary General Low Load Factor"
    elec_chs << "Secondary General"
    elec_chs << "Secondary Photovoltaic Time-of-Use"
    elec_chs << "Transmission General"        
    elec_chs << "Non-Xcel Commercial"
    elec_chs << "Non-Xcel Primary General"
    elec_chs << "Non-Xcel Secondary General Low Load Factor"
    elec_chs << "Non-Xcel Secondary General"
    elec_chs << "Non-Xcel Transmission General"
    elec_tar = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('elec_tar', elec_chs, true)
    elec_tar.setDisplayName("Select an Electricity Tariff.")
    elec_tar.setDefaultValue("Secondary General")
    args << elec_tar
    
    #make an argument for the gas tariff
    gas_chs = OpenStudio::StringVector.new    
    gas_chs << "Residential Gas" 
    gas_chs << "Small CG"
    gas_chs << "Large CG"
    gas_chs << "Interruptible Industrial G"
    gas_chs << "Non-Xcel Gas Firm"
    gas_chs << "Non-Xcel Gas Interruptible"
    gas_tar = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('gas_tar', gas_chs, true)
    gas_tar.setDisplayName("Select a Gas Tariff.")
    gas_tar.setDefaultValue("Large CG")
    args << gas_tar
    
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
    elec_tar = runner.getStringArgumentValue("elec_tar",user_arguments)
    gas_tar = runner.getStringArgumentValue("gas_tar",user_arguments)

    #import the tariffs
    [elec_tar,gas_tar].each do |tar|
    
      #load the idf file containing the electric tariff
      tar_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/#{tar}.idf")
      tar_file = OpenStudio::IdfFile::load(tar_path)

      #in OpenStudio PAT in 1.1.0 and earlier all resource files are moved up a directory.
      #below is a temporary workaround for this before issuing an error.
      if tar_file.empty?
        tar_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{tar}.idf")
        tar_file = OpenStudio::IdfFile::load(tar_path)
      end

      if tar_file.empty?
        runner.registerError("Unable to find the file #{tar}.idf")
        return false
      else
        tar_file = tar_file.get
      end
  

      #add the schedule type limits
      workspace.addObjects(tar_file.getObjectsByType("ScheduleTypeLimits".to_IddObjectType))	
  
      #add the schedules
      workspace.addObjects(tar_file.getObjectsByType("Schedule:Compact".to_IddObjectType))
        
      #add the tariffs
      workspace.addObjects(tar_file.getObjectsByType("UtilityCost:Tariff".to_IddObjectType))
      
      #add the simple charges
      workspace.addObjects(tar_file.getObjectsByType("UtilityCost:Charge:Simple".to_IddObjectType))
      
      #add the block charges
      workspace.addObjects(tar_file.getObjectsByType("UtilityCost:Charge:Block".to_IddObjectType))
    
      #let the user know what happened
      runner.registerInfo("added a tariff named #{tar}")
    
    end
    
    #set the simulation timestep to 15min (4 per hour) to match the demand window of the tariffs
    if not workspace.getObjectsByType("Timestep".to_IddObjectType).empty?
      workspace.getObjectsByType("Timestep".to_IddObjectType)[0].setString(0,"4")
      runner.registerInfo("set the simulation timestep to 15 min to match the demand window of the tariffs")
    else
      runner.registerError("there was no timestep object to alter")
    end
    
    #remove any existing lifecycle cost parameters
    workspace.getObjectsByType("LifeCycleCost:Parameters".to_IddObjectType).each do |object|
      runner.registerInfo("removed existing lifecycle parameters named #{object.name}")
      workspace.removeObjects([object.handle])
    end
    
    #and replace with the FEMP ones
    life_cycle_params_string = "    
    LifeCycleCost:Parameters,
      FEMP LifeCycle Cost Parameters,         !- Name
      EndOfYear,                              !- Discounting Convention
      ConstantDollar,                         !- Inflation Approach
      0.03,                                   !- Real Discount Rate
      ,                                       !- Nominal Discount Rate
      ,                                       !- Inflation
      ,                                       !- Base Date Month
      2011,                                   !- Base Date Year
      ,                                       !- Service Date Month
      2011,                                   !- Service Date Year
      25,                                     !- Length of Study Period in Years
      ,                                       !- Tax rate
      None;                                   !- Depreciation Method	  
    "  
    life_cycle_params = OpenStudio::IdfObject::load(life_cycle_params_string).get
    workspace.addObject(life_cycle_params)
    runner.registerInfo("added lifecycle cost parameters named #{life_cycle_params.name}")
  
  
    #remove any existing lifecycle cost parameters
    workspace.getObjectsByType("LifeCycleCost:UsePriceEscalation".to_IddObjectType).each do |object|
      runner.registerInfo("removed existing fuel escalation rates named #{object.name}")
      workspace.removeObjects([object.handle])
    end  
  
    elec_escalation_string = "
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Electricity,       !- Name
      Electricity,                            !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9838,                                 !- Year Escalation 1
      0.9730,                                 !- Year Escalation 2
      0.9632,                                 !- Year Escalation 3
      0.9611,                                 !- Year Escalation 4
      0.9571,                                 !- Year Escalation 5
      0.9553,                                 !- Year Escalation 6
      0.9539,                                 !- Year Escalation 7
      0.9521,                                 !- Year Escalation 8
      0.9546,                                 !- Year Escalation 9
      0.9550,                                 !- Year Escalation 10
      0.9553,                                 !- Year Escalation 11
      0.9564,                                 !- Year Escalation 12
      0.9575,                                 !- Year Escalation 13
      0.9596,                                 !- Year Escalation 14
      0.9618,                                 !- Year Escalation 15
      0.9614,                                 !- Year Escalation 16
      0.9618,                                 !- Year Escalation 17
      0.9618,                                 !- Year Escalation 18
      0.9593,                                 !- Year Escalation 19
      0.9589,                                 !- Year Escalation 20
      0.9607,                                 !- Year Escalation 21
      0.9625,                                 !- Year Escalation 22
      0.9650,                                 !- Year Escalation 23
      0.9708,                                 !- Year Escalation 24
      0.9751,                                 !- Year Escalation 25
      0.9762,                                 !- Year Escalation 26
      0.9766,                                 !- Year Escalation 27
      0.9766,                                 !- Year Escalation 28
      0.9769,                                 !- Year Escalation 29
      0.9773;                                 !- Year Escalation 30
    "
    elec_escalation = OpenStudio::IdfObject::load(elec_escalation_string).get
    workspace.addObject(elec_escalation)  
    runner.registerInfo("added fuel escalation rates named #{elec_escalation.name}")    

    fuel_oil_1_escalation_string = "
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Distillate Oil,    !- Name
      FuelOil#1,                              !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9714,                                 !- Year Escalation 1
      0.9730,                                 !- Year Escalation 2
      0.9942,                                 !- Year Escalation 3
      1.0164,                                 !- Year Escalation 4
      1.0541,                                 !- Year Escalation 5
      1.0928,                                 !- Year Escalation 6
      1.1267,                                 !- Year Escalation 7
      1.1580,                                 !- Year Escalation 8
      1.1792,                                 !- Year Escalation 9
      1.1967,                                 !- Year Escalation 10
      1.2200,                                 !- Year Escalation 11
      1.2333,                                 !- Year Escalation 12
      1.2566,                                 !- Year Escalation 13
      1.2709,                                 !- Year Escalation 14
      1.2826,                                 !- Year Escalation 15
      1.2985,                                 !- Year Escalation 16
      1.3102,                                 !- Year Escalation 17
      1.3250,                                 !- Year Escalation 18
      1.3261,                                 !- Year Escalation 19
      1.3282,                                 !- Year Escalation 20
      1.3324,                                 !- Year Escalation 21
      1.3356,                                 !- Year Escalation 22
      1.3431,                                 !- Year Escalation 23
      1.3510,                                 !- Year Escalation 24
      1.3568,                                 !- Year Escalation 25
      1.3606,                                 !- Year Escalation 26
      1.3637,                                 !- Year Escalation 27
      1.3674,                                 !- Year Escalation 28
      1.3706,                                 !- Year Escalation 29
      1.3743;                                 !- Year Escalation 30
    "
    fuel_oil_1_escalation = OpenStudio::IdfObject::load(fuel_oil_1_escalation_string).get
    workspace.addObject(fuel_oil_1_escalation)
    runner.registerInfo("added fuel escalation rates named #{fuel_oil_1_escalation.name}")    
      
    fuel_oil_2_escalation_string = "  
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Residual Oil,      !- Name
      FuelOil#2,                              !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.8469,                                 !- Year Escalation 1
      0.8257,                                 !- Year Escalation 2
      0.8681,                                 !- Year Escalation 3
      0.8988,                                 !- Year Escalation 4
      0.9289,                                 !- Year Escalation 5
      0.9604,                                 !- Year Escalation 6
      0.9897,                                 !- Year Escalation 7
      1.0075,                                 !- Year Escalation 8
      1.0314,                                 !- Year Escalation 9
      1.0554,                                 !- Year Escalation 10
      1.0861,                                 !- Year Escalation 11
      1.1278,                                 !- Year Escalation 12
      1.1497,                                 !- Year Escalation 13
      1.1620,                                 !- Year Escalation 14
      1.1743,                                 !- Year Escalation 15
      1.1852,                                 !- Year Escalation 16
      1.1948,                                 !- Year Escalation 17
      1.2037,                                 !- Year Escalation 18
      1.2071,                                 !- Year Escalation 19
      1.2119,                                 !- Year Escalation 20
      1.2139,                                 !- Year Escalation 21
      1.2194,                                 !- Year Escalation 22
      1.2276,                                 !- Year Escalation 23
      1.2365,                                 !- Year Escalation 24
      1.2420,                                 !- Year Escalation 25
      1.2461,                                 !- Year Escalation 26
      1.2509,                                 !- Year Escalation 27
      1.2550,                                 !- Year Escalation 28
      1.2591,                                 !- Year Escalation 29
      1.2638;                                 !- Year Escalation 30
    "
    fuel_oil_2_escalation = OpenStudio::IdfObject::load(fuel_oil_2_escalation_string).get
    workspace.addObject(fuel_oil_2_escalation)
    runner.registerInfo("added fuel escalation rates named #{fuel_oil_2_escalation.name}") 
      
    nat_gas_escalation_string = "
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Natural gas,       !- Name
      NaturalGas,                             !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9823,                                 !- Year Escalation 1
      0.9557,                                 !- Year Escalation 2
      0.9279,                                 !- Year Escalation 3
      0.9257,                                 !- Year Escalation 4
      0.9346,                                 !- Year Escalation 5
      0.9412,                                 !- Year Escalation 6
      0.9512,                                 !- Year Escalation 7
      0.9645,                                 !- Year Escalation 8
      0.9856,                                 !- Year Escalation 9
      1.0067,                                 !- Year Escalation 10
      1.0222,                                 !- Year Escalation 11
      1.0410,                                 !- Year Escalation 12
      1.0610,                                 !- Year Escalation 13
      1.0787,                                 !- Year Escalation 14
      1.0942,                                 !- Year Escalation 15
      1.1098,                                 !- Year Escalation 16
      1.1220,                                 !- Year Escalation 17
      1.1308,                                 !- Year Escalation 18
      1.1386,                                 !- Year Escalation 19
      1.1486,                                 !- Year Escalation 20
      1.1619,                                 !- Year Escalation 21
      1.1763,                                 !- Year Escalation 22
      1.1918,                                 !- Year Escalation 23
      1.2118,                                 !- Year Escalation 24
      1.2284,                                 !- Year Escalation 25
      1.2439,                                 !- Year Escalation 26
      1.2605,                                 !- Year Escalation 27
      1.2772,                                 !- Year Escalation 28
      1.2938,                                 !- Year Escalation 29
      1.3115;                                 !- Year Escalation 30
    "
    nat_gas_escalation = OpenStudio::IdfObject::load(nat_gas_escalation_string).get
    workspace.addObject(nat_gas_escalation) 
    runner.registerInfo("added fuel escalation rates named #{nat_gas_escalation.name}")     
    
    coal_escalation_string = "  
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Coal,              !- Name
      Coal,                                   !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9970,                                 !- Year Escalation 1
      1.0089,                                 !- Year Escalation 2
      1.0089,                                 !- Year Escalation 3
      0.9941,                                 !- Year Escalation 4
      0.9941,                                 !- Year Escalation 5
      1.0000,                                 !- Year Escalation 6
      1.0030,                                 !- Year Escalation 7
      1.0059,                                 !- Year Escalation 8
      1.0089,                                 !- Year Escalation 9
      1.0119,                                 !- Year Escalation 10
      1.0148,                                 !- Year Escalation 11
      1.0178,                                 !- Year Escalation 12
      1.0208,                                 !- Year Escalation 13
      1.0267,                                 !- Year Escalation 14
      1.0297,                                 !- Year Escalation 15
      1.0356,                                 !- Year Escalation 16
      1.0415,                                 !- Year Escalation 17
      1.0534,                                 !- Year Escalation 18
      1.0564,                                 !- Year Escalation 19
      1.0593,                                 !- Year Escalation 20
      1.0653,                                 !- Year Escalation 21
      1.0712,                                 !- Year Escalation 22
      1.0742,                                 !- Year Escalation 23
      1.0801,                                 !- Year Escalation 24
      1.0831,                                 !- Year Escalation 25
      1.0831,                                 !- Year Escalation 26
      1.0861,                                 !- Year Escalation 27
      1.0890,                                 !- Year Escalation 28
      1.0920,                                 !- Year Escalation 29
      1.0950;                                 !- Year Escalation 30
     "
    coal_escalation = OpenStudio::IdfObject::load(coal_escalation_string).get
    workspace.addObject(coal_escalation)             
    runner.registerInfo("added fuel escalation rates named #{coal_escalation.name}")                   
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
XcelEDATariffSelectionandModelSetup.new.registerWithApplication









