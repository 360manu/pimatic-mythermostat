 
module.exports = (env) ->

  class ControllerOnOff

    constructor: (@config, @device) ->
      env.logger.debug "Controller : BangBang"  
      @_interval = setInterval(@_controlHeating, 30 * 1000)

    stop: ->
      clearTimeout @_interval

    setObservedValue: (value) ->
      @_observedValue = value

    setTargetValue: (value) ->
      @_targetValue = value

    _controlHeating: () =>
      # sanity checks
      if @_observedValue is undefined then return
      if @_targetValue is undefined then return
      
      #start heating
      if @_observedValue < @_targetValue - 0.2
        @device.setStatus(true)
        
      # stop heating
      if @_observedValue > @_targetValue + 0.2
        @device.setStatus(false)

  return ControllerOnOff