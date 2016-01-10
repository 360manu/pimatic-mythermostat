module.exports = {
  title: "my-thermostat device config schemas"
  MyHeatingThermostat: {
    title: "MyHeatingThermostat config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      comfyTemp:
        description: "The defined comfy temperature"
        type: "number"
        default: 21
      ecoTemp:
        description: "The defined eco mode temperature"
        type: "number"
        default: 17
      controller:
        description: "The controller [BangBang, PID]"
        type: "string"
        default: "BangBang"      
      variableTemp:
        description: "The observed temperature variable name"
        type: "string"
        default: "tempsalon.temperature"  
      actionHeatingOn:
        description: "The action to start heating the room"
        type: "string"
        default: "press heat-on-button and set presence of heatingindicator present"   
      actionHeatingOff:
        description: "The action to stop heating the room"
        type: "string"
        default: "press heat-off-button and set presence of heatingindicator absent"

      programs:
        description: "The different confort zone"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          properties:
            id:
              type: "integer"
              default: 0
            temperature:
              type: "number" 
              default: 21

      timetable:
        description: "thermostat schedule"
        type: "array"
        default: []
        format: "table"
        items:
          type: "object"
          properties:
            day:
              type: "string"
              default: "Mon" 
            schedule:
              type: "array"
              default: []
              format: "table"
              items:
                properties:
                  start:
                    type: "string"
                    default: "0000"
                  programID:
                    type: "integer"   
                    default: 0
  }
}
