module.exports = (env) ->
  Promise = env.require 'bluebird'
  ModeScheduled = require('./mode_Scheduled')(env)
  ModeManual = require('./mode_Manual')(env)
  ControllerOnOff = require('./controller_ON_OFF')(env)
  ControllerPID = require('./controller_PID')(env)

  class MyThermostat extends env.plugins.Plugin
 
    init: (app, @framework, @config) => 
      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("MyHeatingThermostat", {
        configDef: deviceConfigDef.MyHeatingThermostat,
        createCallback: (config, lastState) -> new MyHeatingThermostat(config, lastState)
      })

      # wait till all plugins are loaded
      @framework.on "after init", =>
        # Check if the mobile-frontend was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-mythermostat/app/mythermostat-page.coffee"
          mobileFrontend.registerAssetFile 'css', "pimatic-mythermostat/app/mythermostat-template.css"
          mobileFrontend.registerAssetFile 'html', "pimatic-mythermostat/app/mythermostat-template.jade"
        else
          env.logger.warn "your plugin could not find the mobile-frontend. No gui will be available"

  plugin = new MyThermostat
 
  class MyHeatingThermostat extends env.devices.Device
    attributes:
      temperatureSetpoint:
        label: "Temperature Setpoint"
        description: "The temp that should be set"
        type: "number"
        discrete: true
        unit: '°C'
      mode:
        description: "The current mode"
        type: "string"
        enum: ["auto", "manu", "off"]
      status:
        description: "The current heating status"
        type: "boolean" 
      currentProgram:
        description: "The current program"
        type: "array" 
        hidden: true

    actions:
      changeModeTo:
        params: 
          mode: 
            type: "string"
      changeTemperatureTo:
        params: 
          temperatureSetpoint: 
            type: "number"

    template: "mythermostat"

    _mode: null
    _temperatureSetpoint: null
    _currentProgram: null
    _status: false
    _observedName: null
    _observedValue: 0

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      
      #init controller specified via config
      if @config.controller == "PID"
        @controller = new ControllerPID(@config, this)
      else
        @controller = new ControllerOnOff(@config, this)

      #last state of the system
      @setTemperatureSetpoint(lastState?.temperatureSetpoint?.value or 20)
      @setStatus(lastState?.status?.value or false)

       #init both mode
      @modeSchedule = new ModeScheduled(@config, this)
      @modeManual = new ModeManual(@_temperatureSetpoint, this)
      @setMode(lastState?.mode?.value or "auto")

      #start observing the state of the system
      @_startObservation()

      #call device constructor
      super()

    destroy: () ->
      # shutdown device, i.e., remove Timers, de-register event handlers registered with the framework
      @modeSchedule.stop()
      @modeManual.stop()
      @_vars.removeListener("variableAdded", @_variableAddedListener)
      @_vars.removeListener("variableValueChanged", @_variableValueChangedListener)
      super()

    # Getter / Setter of attributes
    getMode: () -> 
      Promise.resolve(@_mode)

    setMode: (mode) ->
      if mode is @_mode then return
      # stop old mode
      @_getActiveMode().setActive(false)
      @_mode = mode
      # activate new one
      @_getActiveMode().setActive(true)
      @emit "mode", @_mode

    getStatus: () -> 
      Promise.resolve(@_status)

    setStatus: (status) ->
      if status is @_status then return
      @_status = status
      if status
        plugin.framework.ruleManager.executeAction(@config.actionHeatingOn)
      else
        plugin.framework.ruleManager.executeAction(@config.actionHeatingOff)
      @emit "status", @_status

    getTemperatureSetpoint: () -> 
      Promise.resolve(@_temperatureSetpoint)

    setTemperatureSetpoint: (temperatureSetpoint) ->
       #let's the controller know 
      @controller.setTargetValue(temperatureSetpoint)
      # issue event
      if temperatureSetpoint is @_temperatureSetpoint then return
      @_temperatureSetpoint = temperatureSetpoint
      @emit "temperatureSetpoint", @_temperatureSetpoint

    getCurrentProgram: () -> 
      return Promise.resolve(@_currentProgram)

    setCurrentProgram: (program) ->
      @_currentProgram = program
      @emit "currentProgram", @_currentProgram

    # Actions : called from UI & rules
    changeModeTo: (mode) -> 
      @setMode(mode)
      return Promise.resolve()
      
    changeTemperatureTo: (temperatureSetpoint) -> 
      @_getActiveMode().setTemperature(temperatureSetpoint)
      return Promise.resolve()

    # event and anticipation
    setNextEvent: (ev) ->
      # here we can anticipate the next state
      # preheat or stop heating 
      return true

    # private functions
    _getActiveMode: ->
      switch @_mode
        when 'auto'
          return @modeSchedule
        when 'manu'
          return @modeManual
      # default mode
      return @modeManual

    _startObservation: ->
       #observe target temperature
      @_observedName = @config.variableTemp
      @_vars = plugin.framework.variableManager
      # wait till variable is added
      @_vars.on "variableAdded", @_variableAddedListener = (variable) =>
        if variable.name is @_observedName
          @_setObservedValue(variable.getCurrentValue())
      # when variable is updated
      @_vars.on "variableValueChanged", @_variableValueChangedListener = (variable, value) =>
        if variable.name is @_observedName
          @_setObservedValue(value)

    _setObservedValue: (value) ->
      @controller.setObservedValue(value)

  return plugin
