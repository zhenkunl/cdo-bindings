$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'cdo'
require 'pp'

class TestCdo < Test::Unit::TestCase

  DEFAULT_CDO_PATH = 'cdo'

  def test_cdo
    assert_equal(true,Cdo.checkCdo)
    if ENV['CDO']
      assert_equal(ENV['CDO'],Cdo.getCdo)
    else
      assert_equal(DEFAULT_CDO_PATH,Cdo.getCdo)
    end
    newCDO="#{ENV['HOME']}/bin/cdo"
    if File.exist?(newCDO) then
      Cdo.setCdo(newCDO)
      assert_equal(true,Cdo.checkCdo)
      assert_equal(newCDO,Cdo.getCdo)
    end
  end
  def test_getOperators
    %w[for random stdatm info showlevel sinfo remap geopotheight mask topo thicknessOfLevels].each {|op|
      if ["thicknessOfLevels"].include?(op)
        assert(Cdo.respond_to?(op),"Operator '#{op}' not found")
      else
        assert(Cdo.getOperators.include?(op),"Operator '#{op}' not found")
      end
    }
  end
  def test_listAllOperators
    print Cdo.operators.join("\n")
  end

  def test_outputOperators
    Cdo.debug = true
    levels = Cdo.showlevel(:in => "-stdatm,0")
    assert_equal([0,0].map(&:to_s),levels)

    info = Cdo.sinfo(:in => "-stdatm,0")
    assert_equal("File format: GRIB",info[0])

    values = Cdo.outputkey("value",:in => "-stdatm,0")
    assert_equal(["1013.25", "288"],values)
    values = Cdo.outputkey("value",:in => "-stdatm,0,10000")
    assert_equal(["1013.25", "271.913", "288", "240.591"],values)
    values = Cdo.outputkey("level",:in => "-stdatm,0,10000")
    assert_equal(["0", "10000","0", "10000"],values)
  end
  def test_CDO_version
    assert("1.4.3.1" < Cdo.version,"Version to low: #{Cdo.version}")
  end
  def test_args
    #Cdo.Debug = true
    #MyTempfile.setPersist(true)
    ofile0 = MyTempfile.path
    ofile1 = MyTempfile.path
    ofile2 = MyTempfile.path
    ofile3 = MyTempfile.path
    Cdo.stdatm(0,20,40,80,200,230,400,600,1100,:out => ofile0)
    Cdo.intlevel(0,10,50,100,500,1000,  :in => ofile0,:out => ofile1)
    Cdo.intlevel([0,10,50,100,500,1000],:in => ofile0,:out => ofile2)
    Cdo.sub(:in => [ofile1,ofile2].join(' '),:out => ofile3)
    info = Cdo.infon(:in => ofile3)
    (1...info.size).each {|i| assert_equal(0.0,info[i].split[-1].to_f)}
  end
  def test_operator_options
    ofile = MyTempfile.path
    targetLevels = [0,10,50,100,200,400,1000]
    Cdo.stdatm(targetLevels,:out => ofile)
    levels = Cdo.showlevel(:in => ofile)
    [0,1].each {|i| assert_equal(targetLevels.map(&:to_s),levels[i].split)}
  end
  def test_CDO_options
    names = Cdo.showname(:in => "-stdatm,0",:options => "-f nc")
    assert_equal(["P T"],names)

    ofile = MyTempfile.path
    Cdo.topo(:out => ofile,:options => "-z szip")
    assert_equal(["GRIB SZIP"],Cdo.showformat(:in => ofile))
  end
  def test_chain
    ofile     = MyTempfile.path
    Cdo.Debug = true
    Cdo.setname('veloc',:in => " -copy -random,r1x1",:out => ofile,:options => "-f nc")
    assert_equal(["veloc"],Cdo.showname(:in => ofile))
  end

  def test_diff
    diffv = Cdo.diffn(:in => "-random,r1x1 -random,r1x1")
    assert_equal(diffv[1].split(' ')[-1],"random")
    assert_equal(diffv[1].split(' ')[-3],"0.53060")
    diff  = Cdo.diff(:in => "-random,r1x1 -random,r1x1")
    assert_equal(diff[1].split(' ')[-3],"0.53060")
  end

  def test_operators
    assert_includes(Cdo.operators,"infov")
    assert_includes(Cdo.operators,"showlevel")
  end

  def test_bndLevels
    ofile = MyTempfile.path
    Cdo.stdatm(25,100,250,500,875,1400,2100,3000,4000,5000,:out => ofile,:options => "-f nc")
    assert_equal([0, 50.0, 150.0, 350.0, 650.0, 1100.0, 1700.0, 2500.0, 3500.0, 4500.0, 5500.0],
                 Cdo.boundaryLevels(:in => "-selname,T #{ofile}"))
    assert_equal([50.0, 100.0, 200.0, 300.0, 450.0, 600.0, 800.0, 1000.0, 1000.0, 1000.0],
                 Cdo.thicknessOfLevels(:in => ofile))
  end

  def test_combine
    ofile0, ofile1 = MyTempfile.path, MyTempfile.path
    Cdo.fldsum(:in => Cdo.stdatm(25,100,250,500,875,1400,2100,3000,4000,5000,:options => "-f nc"),:out => ofile0)
    Cdo.fldsum(:in => "-stdatm,25,100,250,500,875,1400,2100,3000,4000,5000",:options => "-f nc",:out => ofile1)
    Cdo.setReturnCdf
    MyTempfile.showFiles
    diff = Cdo.sub(:in => [ofile0,ofile1].join(' ')).var('T').get
    assert_equal(0.0,diff.min)
    assert_equal(0.0,diff.max)
    Cdo.setReturnCdf(false)
  end

  def test_tempfile
    ofile0, ofile1 = MyTempfile.path, MyTempfile.path
    assert_not_equal(ofile0,ofile1)
    # Tempfile should not disappeare even if the GC was started
    puts ofile0
    assert(File.exist?(ofile0))
    GC.start
    assert(File.exist?(ofile0))
  end

  def test_returnCdf
    ofile = MyTempfile.path
    vals = Cdo.stdatm(25,100,250,500,875,1400,2100,3000,4000,5000,:out => ofile,:options => "-f nc",:force => true)
    assert_equal(ofile,vals)
    Cdo.setReturnCdf
    vals = Cdo.stdatm(25,100,250,500,875,1400,2100,3000,4000,5000,:out => ofile,:options => "-f nc")
    assert_equal(["lon","lat","level","P","T"],vals.var_names)
    assert_equal(276,vals.var("T").get.flatten.mean.floor)
    Cdo.unsetReturnCdf
    vals = Cdo.stdatm(25,100,250,500,875,1400,2100,3000,4000,5000,:out => ofile,:options => "-f nc")
    assert_equal(ofile,vals)
  end
  def test_simple_returnCdf
    ofile0, ofile1 = MyTempfile.path, MyTempfile.path
    sum = Cdo.fldsum(:in => Cdo.stdatm(0,:options => "-f nc"),
               :returnCdf => true).var("P").get
    assert_equal(1013.25,sum.min)
    sum = Cdo.fldsum(:in => Cdo.stdatm(0,:options => "-f nc"),:out => ofile0)
    assert_equal(ofile0,sum)
    test_returnCdf
  end
  def test_force
    outs = []
    # tempfiles
    outs << Cdo.stdatm(0,10,20)
    outs << Cdo.stdatm(0,10,20)
    assert_not_equal(outs[0],outs[1])

    # deticated output, force = true
    outs.clear
    outs << Cdo.stdatm(0,10,20,:out => 'test_force')
    mtime0 = File.stat(outs[-1]).mtime
    outs << Cdo.stdatm(0,10,20,:out => 'test_force')
    mtime1 = File.stat(outs[-1]).mtime
    assert_not_equal(mtime0,mtime1)
    assert_equal(outs[0],outs[1])
    FileUtils.rm('test_force')
    outs.clear

    # dedicated output, force = false
    ofile = 'test_force_false'
    outs << Cdo.stdatm(0,10,20,:out => ofile,:force => false)
    mtime0 = File.stat(outs[-1]).mtime
    outs << Cdo.stdatm(0,10,20,:out => ofile,:force => false)
    mtime1 = File.stat(outs[-1]).mtime
    assert_equal(mtime0,mtime1)
    assert_equal(outs[0],outs[1])
    FileUtils.rm(ofile)
    outs.clear

    # dedicated output, global force setting
    ofile = 'test_force_global'
    Cdo.forceOutput = false
    outs << Cdo.stdatm(0,10,20,:out => ofile)
    mtime0 = File.stat(outs[-1]).mtime
    outs << Cdo.stdatm(0,10,20,:out => ofile)
    mtime1 = File.stat(outs[-1]).mtime
    assert_equal(mtime0,mtime1)
    assert_equal(outs[0],outs[1])
    FileUtils.rm(ofile)
    outs.clear
  end

  def test_thickness
    levels            = "25 100 250 500 875 1400 2100 3000 4000 5000".split
    targetThicknesses = [50.0,  100.0,  200.0,  300.0,  450.0,  600.0,  800.0, 1000.0, 1000.0, 1000.0]
    assert_equal(targetThicknesses, Cdo.thicknessOfLevels(:in => "-selname,T -stdatm,#{levels.join(',')}"))
  end

  def test_showlevels
    sourceLevels = %W{25 100 250 500 875 1400 2100 3000 4000 5000}
    assert_equal(sourceLevels,
                 Cdo.showlevel(:in => "-selname,T #{Cdo.stdatm(*sourceLevels,:options => '-f nc')}")[0].split)
  end

  def test_verticalLevels
    targetThicknesses = [50.0,  100.0,  200.0,  300.0,  450.0,  600.0,  800.0, 1000.0, 1000.0, 1000.0]
    sourceLevels = %W{25 100 250 500 875 1400 2100 3000 4000 5000}
    thicknesses = Cdo.thicknessOfLevels(:in => "-selname,T #{Cdo.stdatm(*sourceLevels,:options => '-f nc')}")
    assert_equal(targetThicknesses,thicknesses)
  end

  def test_parseArgs
    io,opts = Cdo.parseArgs([1,2,3,:in => '1',:out => '2',:force => true,:returnCdf => "T"])
    assert_equal("1",io[:in])
    assert_equal("2",io[:out])
    assert_equal(true,io[:force])
    assert_equal("T",io[:returnCdf])
    pp [io,opts]
  end 

  if 'thingol' == `hostname`.chomp  then
    def test_readCdf
      input = "-settunits,days  -setyear,2000 -for,1,4"
      cdfFile = Cdo.copy(:options =>"-f nc",:in=>input)
      cdf     = Cdo.readCdf(cdfFile)
      assert_equal(['lon','lat','time','for'],cdf.var_names)
    end
    def test_tmp
      tempfilesStart = Dir.glob('/tmp/Module*').sort
      tempfilesEnd   = Dir.glob('/tmp/Module*').sort
      assert_equal(tempfilesStart,tempfilesEnd)
      test_combine()
      tempfilesEnd = Dir.glob('/tmp/Module**')
      assert_empty(tempfilesStart-tempfilesEnd)
    end
    def test_selIndexListFromIcon
      input = "~/data/icon/oce.nc"
    end
  end

end

#  # Calling simple operators
#  #
#  # merge:
#  #   let files be an erray of valid filenames and ofile is a string
#  Cdo.merge(:in => outvars.join(" "),:out => ofile)
#  #   or with multiple arrays:
#  Cdo.merge(:in => [ifiles0,ifiles1].flatten.join(' '),:out => ofile)
#  # selname:
#  #   lets grep out some variables from ifile:
#  ["T","U","V"].each {|varname|
#    varfile = varname+".nc"
#    Cdo.selname(varname,:in => ifile,:out => varfile)
#  }
#  #   a threaded version of this could look like:
#  ths = []
#  ["T","U","V"].each {|outvar|
#    ths << Thread.new(outvar) {|ovar|
#      varfile = varname+".nc"
#      Cdo.selname(varname,:in => ifile,:out => varfile)
#    }
#  }
#  ths.each {|th| th.join}
#  # another example with sub:
#  Cdo.sub(:in => [oldfile,newfile].join(' '), :out => diff)
#  
#  # It is possible too use the 'send' method
#  operator  = /grb/.match(File.extname(ifile)) ? :showcode : :showname
#  inputVars = Cdo.send(operator,:in => ifile)
#  # show and info operators are writing to stdout. cdo.rb tries to collects this into arrays
#  #
#  # Same stuff with other operators:
#  operator = case var
#             when Fixnum then 'selcode'
#             when String then 'selname'
#             else
#               warn "Wrong usage of variable identifier for '#{var}' (class #{var.class})!"
#             end
#  Cdo.send(operator,var,:in => @ifile, :out => varfile)
#  
#  # Pass an array for operators with multiple options:
#  #   Perform conservative remapping with pregenerated weights
#  Cdo.remap([gridfile,weightfile],:in => copyfile,:out => outfile)
#  #   Create vertical height levels out of hybrid model levels
#  Cdo.ml2hl([0,20,50,100,200,400,800,1200].join(','),:in => hybridlayerfile, :out => reallayerfile)
#  # or use multiple arguments directly
#  Cdo.remapeta(vctfile,orofile,:in => ifile,:out => hybridlayerfile)
#  
#  # the powerfull expr operator:
#  # taken from the tutorial in https://code.zmaw.de/projects/cdo/wiki/Tutorial#The-_expr_-Operator
#  SCALEHEIGHT  = 10000.0
#  C_EARTH_GRAV = 9.80665
#  # function for later computation of hydrostatic atmosphere pressure
#  PRES_EXPR    = lambda {|height| "101325.0*exp((-1)*(1.602769777072154)*log((exp(#{height}/#{SCALEHEIGHT})*213.15+75.0)/288.15))"}
#  TEMP_EXPR    = lambda {|height| "213.0+75.0*exp(-#{height}/#{SCALEHEIGHT})"}
#  
#  # Create Pressure and Temperature out of a height field 'geopotheight' from ifile
#  Cdo.expr("'p=#{PRES_EXPR['geopotheight']}'", :in => ifile, :out => presFile)
#  Cdo.expr("'t=#{TEMP_EXPR['geopotheight']}'", :in => ifile, :out => tempFile)
#  
#  
#  # TIPS: I often work with temporary files and for getting rid of handling them manually the MyTempfile module can be used:
#  #       Simply include the following methods into you scripts and use tfile for any temporary variable
#  def tfile
#    MyTempfile.path
#  end
#  # As an example, the computation of simple atmospherric density could look like
#  presFile, tempFile = tfile, tfile
#  Cdo.expr("'p=#{PRES_EXPR['geopotheight']}'", :in => ifile, :out => presFile)
#  Cdo.expr("'t=#{TEMP_EXPR['geopotheight']}'", :in => ifile, :out => tempFile)
#  Cdo.chainCall("setname,#{rho} -divc,#{C_R} -div",in: [presFile,tempFile].join(' '), out: densityFile)
#  
#  # For debugging, it is helpfull, to avoid the automatic cleanup at the end of the scripts:
#  MyTempfile.setPersist(true)
#  # creates randomly names files. Switch on debugging with 
#  Cdo.Debug = true
