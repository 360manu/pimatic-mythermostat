$(document).on( "templateinit", (event) ->

  class MyThermostatItem extends pimatic.DeviceItem
    
    constructor: (templData, @device) ->
      super(templData, @device)
      #init arrays
      @weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
      @heatmap = ["#3A4FC7", "#386DAC", "#368B91", "#34A976", "#32C75C", "#64A151", "#977C47", "#C9573C", "#FC3232"]
    
      # The value in the input : http://jsfiddle.net/v0bb7fco/
      @inputValue = ko.observable()

      # temperatureSetpoint changes -> update input + also update buttons if needed
      @stAttr = @getAttribute('temperatureSetpoint')
      @inputValue(@stAttr.value())

      attrValue = @stAttr.value()
      @stAttr.value.subscribe( (value) =>
        @inputValue(value)
        attrValue = value
      )

      # input changes -> call changeTemperature
      ko.computed( =>
        textValue = @inputValue()
        if textValue? and attrValue? and parseFloat(attrValue) isnt parseFloat(textValue)
          @changeTemperatureTo(parseFloat(textValue))
      ).extend({ rateLimit: { timeout: 1000, method: "notifyWhenChangesStop" } })

    afterRender: (elements) ->
      super(elements)
      # find the buttons
      @autoButton = $(elements).find('[name=autoButton]')
      @manuButton = $(elements).find('[name=manuButton]')
      @offButton = $(elements).find('[name=offButton]')
      @program = $(elements).find('[name=program]')
     
      @statusPosition = $(elements).find('.valve-position-bar')
      @input = $(elements).find('.spinbox input')
      @input.spinbox()

      @updateButtons()
      @updateStatusPosition()

      @getAttribute('mode').value.subscribe( => @updateButtons() )
      @getAttribute('status')?.value.subscribe( => @updateStatusPosition() )
      return

    # define the available actions for the template
    dayname: -> 
      d = new Date()
      return @weekday[d.getDay()]

    modeAuto: -> @changeModeTo "auto"
    modeManu: -> @changeModeTo "manu"
    modeOff: -> @changeModeTo "off"
    setTemp: -> @changeTemperatureTo "#{@inputValue.value()}"
    getCurrentProgram: -> 
      prog = @getAttribute('currentProgram').value()
      sum = 0
      largeur =  80 / 72
      currentdate = new Date()
      offset = currentdate.getMinutes() + currentdate.getHours() * 60

      #sanity check
      table = []
      if prog == null
        return table

      #first zone
      currentZone = 0 
      zone = prog[currentZone]    
      time = 0
      
      for l in [0..71]     
       if time >= zone.end
          currentZone++
          if (currentZone < prog.length)
            zone = prog[currentZone]            
        # program temperature
        t = zone.temp / 25 * 100
        if Math.abs(time - offset) < 1440 / 143
          blink = "blink"
        else
          blink = ""
        bar = {blinking : "#{blink}", sumpercent : "#{sum}%", temppercent: "#{t}%", percent:"#{largeur}%", tempcolor:@heatMapColorforValue(zone.temp)}
        table.push(bar)
        sum += 99 / 72
        time += 1440 / 72
      return table

    heatMapColorforValue: (value) ->
      index = (value - 17) / (21 - 17) * 8
      index = Math.max(0, Math.min(index, 8))
      return @heatmap[parseInt(index, 10)]
 
    updateButtons: ->
      modeAttr = @getAttribute('mode').value()
      switch modeAttr
        when 'auto'
          @manuButton.removeClass('ui-btn-active')
          @offButton.removeClass('ui-btn-active')
          @autoButton.addClass('ui-btn-active')
          @showAutoMode()
        when 'manu'
          @manuButton.addClass('ui-btn-active')
          @offButton.removeClass('ui-btn-active')
          @autoButton.removeClass('ui-btn-active')
          @showManualMode()
        when 'off'
          @manuButton.removeClass('ui-btn-active')
          @offButton.addClass('ui-btn-active')
          @autoButton.removeClass('ui-btn-active')    
          @showManualMode()    
      return
 
    showAutoMode: ->
      #@input.parent().parent().css('display', 'none')
      @program.css('display', '')
 
    showManualMode: ->
      #@input.parent().parent().css('display', '')
      @program.css('display', 'none')

    updateStatusPosition: ->
      valveVal = @getAttribute('status')?.value()
      if valveVal
        @statusPosition.css('height', "#100%")
        @statusPosition.parent().css('display', '')
      else
        @statusPosition.parent().css('display', 'none')

    changeModeTo: (mode) ->
      @device.rest.changeModeTo({mode}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

    changeTemperatureTo: (temperatureSetpoint) ->
      @input.spinbox('disable')
      @device.rest.changeTemperatureTo({temperatureSetpoint}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
        .always( => @input.spinbox('enable') )

    getConfig: (name) ->
      if @device.config[name]?
        return @device.config[name]
      else
        return @device.configDefaults[name]


  # register the item-class
  pimatic.templateClasses['mythermostat'] = MyThermostatItem
)  