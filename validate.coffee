module.exports = 
  type: "object"
  properties:
    security:
      type: 'object'
      required: ['header_token'] 
      properties:
        header_token: 
          type: 'string'
          default: 'X-Foo-Token'
