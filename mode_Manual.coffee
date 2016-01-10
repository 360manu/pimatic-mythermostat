 
module.exports = (env) ->
  ModeBase = require('./mode_Base')(env)
  
  class ModeManual extends ModeBase
    constructor: (initialTemperature, device) ->
      @setTemperature(initialTemperature)
      super(device)

    # manually set the objective temperature
    setTemperature: (temperature) ->
      @temp = temperature
      # execute
      if @active then @device.setTemperatureSetpoint(@temp)
      
    # prepare the activation of the mode
    activate: ->
      @device.setTemperatureSetpoint(@temp)
      @cb = setTimeout(@callback, 3 * 3600 * 1000) # 3 hours -> switch to auto
      
    stop: ->
      # remove callback
      if @cb? 
        clearTimeout(@cb)
        @cb = null

    _callback: =>
      # come back to auto mode
      @device.setMode("Auto")

  return ModeManual