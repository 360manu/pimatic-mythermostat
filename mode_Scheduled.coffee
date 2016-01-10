 
module.exports = (env) ->
  ModeBase = require('./mode_Base')(env)
  
  class ModeScheduled extends ModeBase
    days : [ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" , "Sun" ]

    constructor: (config, device) ->
      @config = config
      super(device)

      # save the different target temp
      @TempForProg = []
      for c in @config.programs
        @TempForProg[c.id] = c.temperature
      if @TempForProg.length is 0
        @TempForProg = [@config.ecoTemp]

      # check timetable and tranform as offset in minute from 00h00
      @timetables = []
      for zone in @config.timetable
        i = @days.indexOf(zone.day)
        table = @_convertScheduleToTimetable(zone.schedule)
        #save timetable
        @timetables[i] = table

      for i in [0 ..7]
        if @timetables[i] is undefined
          @timetables[i] = [{end:0, prog:0}, {end:1440, prog:0}]   # default or empty = full day program

      # current situation = -1 to force new program & new temperature
      @currentDay = -1
      @currentProg = null
      @func = @getNextEvent

    # manually set the objective temperature
    setTemperature: (temperature) ->
      # execute
      if @active 
        @device.setTemperatureSetpoint(temperature)
        if @currentProg?
          @_updateProgram(@currentProg, temperature)
          @device.setCurrentProgram(@currentProg)

    # prepare the activation of the mode
    # start program event loop
    activate: ->
      env.logger.debug "Activating scheduled"
      if @cb? 
        clearTimeout(@cb)
        @cb = null
      # start the next event
      @getNextEvent()

    # stop the current event loop
    stop: ->
      env.logger.debug "Stopping scheduled"
      # remove latest callback
      if @cb? 
        clearTimeout(@cb)
        @cb = null

    # return the next event
    getNextEvent: ->
      currentdate = new Date()
      d = @_getDayOfWeek(currentdate)

      #new program ?
      if d != @currentDay
        env.logger.debug "Set new program"
        @currentDay = d
        @currentProg = @_getCurrentProgram(d)
        @device.setCurrentProgram(@currentProg)

      # just set the temperature
      offset = currentdate.getMinutes() + currentdate.getHours() * 60
      #program id
      id = 0
      for zone in @timetables[d]
        # find the zone after this one and return the current zone
        if offset < zone.end 
          @device.setTemperatureSetpoint(@TempForProg[id])
          # set the next temperature when it will change zone
          env.logger.debug "Next event will happen in #{zone.end  - offset + 1} minutes"
          @cb = setTimeout( (=> @func()) , (zone.end  - offset + 1) * 60 * 1000)
          return
        id = zone.prog

      env.logger.debug "Not Found set to Eco = #{@config.ecoTemp}"
      @device.setTemperatureSetpoint(@config.ecoTemp)
      @cb = setTimeout( (=> @func()) , 30 * 60 * 1000) # try again in 30 min


     # private helpers
    _getCurrentProgram: (dayOfWeek) ->
      prog = []
      id = 0
      for zone in @timetables[dayOfWeek]
        if zone.end > 0
          prog.push({end:zone.end, temp:@TempForProg[id]})
        id = zone.prog
      return prog

    _updateProgram: (program, temperature) ->
      currentdate = new Date()
      offset = currentdate.getMinutes() + currentdate.getHours() * 60

      for i in [0 .. program.length]
        zone = program[i]
        if offset < zone.end 
          # zone is found : insert the new one if necessary otherwize, just update the zone
          if (i > 0) && (offset - program[i-1].end > 15)
            newZone = {end:offset - 1, temp:zone.temp}
            program.splice(i, 0, newZone)
          # change the future temp
          zone.temp = temperature
          return

    _getDayOfWeek: (currentdate) ->
      d = currentdate.getDay() - 1
      if d < 0 then d = 6 # sunday is 6 !! :)
      return d

    _convertScheduleToTimetable: (schedule) ->
      table = []
      #first default prog
      table.push({end:0, prog:0})
      
      #compute offset for each time zone
      for zone in schedule 
        lastZone = @_convertToOffset(zone.start)
        #if first point is 0, just replace the program id
        if lastZone == 0
          table[0].prog = zone.programID
        else
          table.push({end:lastZone, prog:zone.programID})

      #fill last zone with default program
      if lastZone != 1440 
        table.push({end:1440, prog:0})
      return table

    _convertToOffset: (zoneStart) ->
      #convert to number of minute : 2400 -> 1440
      t = parseInt(zoneStart)
      t = Math.floor(t/100) * 60 + t % 100 
      return t

  return ModeScheduled