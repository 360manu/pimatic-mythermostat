 
module.exports = (env) ->

  class ControllerPID

    constructor: (@config, @device) ->
      env.logger.debug "Controller : PID"  
      #PID constants
      Tu = 90.0 # in minute
      @k_p = 100  # error = 1 degree -> 100% of the windows size
      @k_i = 0.0 * 2.0 * @k_p / Tu
      @k_d = 0.0 * @k_p * Tu / 8.0
      
      @sumError  = 0    
      @lastError = 0    
      @windowStartTime = @lastTime  = Date.now()    
      @windowSize = 30
      @minRelayOn = 5

      @_interval = setInterval(@_controlHeating, 30 * 1000)
       
    setObservedValue: (value) ->
      env.logger.debug "observed #{value}"
      @_observedValue = value

    setTargetValue: (value) ->
      env.logger.debug "target #{value}"
      if @_targetValue is value then  return
      @_targetValue = value
      #reset window
      @windowStartTime = Date.now()    
      @_reset()

    _controlHeating: () =>
      # sanity checks
      if @_observedValue is undefined then return
      if @_targetValue is undefined then return

      # Calculate dt
      currentTime = Date.now()    
      dt = (currentTime - @lastTime) / 60000     # in minutes

      #error
      error = (@_targetValue - @_observedValue)

      #integral 
      @sumError += error * dt  
      @sumError = Math.max(0, Math.min(100, @sumError))   
      
      #derivative
      dError = (error - @lastError)/dt   
      
      #store
      @lastError = error    
      @lastTime = currentTime   

      output = (@k_p * error) + (@k_i * @sumError) + (@k_d * dError)  
      output = Math.round(Math.max(0, Math.min(100, output)) / 20.0) * 20.0 # round by step of 5%
      outWindow = output / 100.0 * @windowSize 

      #time to shift the Relay Window
      windows = (currentTime - @windowStartTime) / 60000
      if (windows > @windowSize)
        @windowStartTime += @windowSize * 60000
 
      if ((outWindow >  @minRelayOn) && (outWindow > windows)) #X min minimum
        @device.setStatus(true)
      else
        @device.setStatus(false)

      env.logger.debug "t = #{windows} min - On for #{output}% = #{outWindow} min "

    _reset: () -> 
      @sumError  = 0    
      @lastError = 0    
      @lastTime  = 0    

  return ControllerPID