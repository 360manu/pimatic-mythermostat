 
module.exports = (env) ->

  class ModeBase
    constructor: (@device) ->
      @active = false
    
    # is this mode active ?
    isActive: ->
      return @active

    setActive: (state) ->
      if (@active == state) then return
      @active = state
      if (@active)
        @activate()
      else
        @stop()

    # set temperature : must be implemented
    setTemperature: (temperature) ->

    # Must be implemented by the children
    # prepare the activation of the mode
    activate: ->

    # Must be implemented by the children
    # prepare the de-activation of the mode
    stop: ->

  return ModeBase