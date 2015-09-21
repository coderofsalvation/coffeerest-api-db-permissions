JSVD = require('./../coffeerest-api/node_modules/json-schema-defaults')

module.exports = (server,model,lib, urlprefix) ->

  me = @
  @.db  = false
  @.lib = lib
  @.user = false 
  @.model = model
      
  @.security_enabled = () ->
    return false if @.lib.user.is_god? and @.lib.user.is_god
    return true
   

  lib.events.addListener 'beforeDbSchemaCreate', (schema, next) ->
    if schema.identity is 'user'  

      # turn strings like 'can update,create user email' in to 'can update user email' and 'can create user email'
      schema.attributes.tags_flatten_explode = () ->
        permissions = {}
        for tag in @.tags_flatten()
          continue if not tag.match(/^can/)
          tagparts   = tag.split(' ')
          allowed    = tagparts[0]
          operations  = tagparts[1].split(',')
          cname      = tagparts[2] 
          for operation in operations
            if tagparts.length is 3 
              permissions[allowed+" "+operation+" "+cname ] = true 
              continue
            field      = tagparts[3]
            permissions[allowed+" "+operation+" "+cname+" "+tagparts[3] ] = true if tagparts.length is 4
        return permissions

      # generate permissionstrings based on data and see if they match
      # and if they do, delete the field
      schema.attributes.strip_data = ( data, collectionname, type ) ->
        permissions = @.tags_flatten_explode()
        console.dir @
        permission = "can "+type+" "+collectionname
        return true if permissions[permission]
        for field,value of data 
          permissionfield=permission+" "+field
          if not permissions[permissionfield]?
            console.log "removing "+field+" from data because user is not tagged with '"+permissionfield+"'"
            delete data[field]

      # can user access collection?
      schema.attributes.can_access = ( collection ) ->
        colname = collection.identity
        permissions = @.tags_flatten_explode()
        console.dir permissions
        for operation in ["read","create","update","delete"]
          return true if permissions[ "can "+operation+" "+colname ]?
        return false
    return next()

  # on each rest request, check if user has permissions 
  # to collection(fields) based on requiretag-keys set on resource schemaconfig
  lib.events.on 'beforeStart', (data, next) ->
    server = data.server 
    model  = data.model 
    lib    = data.lib 
    urlprefix = data.urlprefix 

    me.db = me.lib.extensions['coffeerest-api-db']
    console.log "setting up user & data security"

    me.db.events.addListener 'onResourceCall', (data, next) ->
      res = data.res 
      req = data.req
      model = me.model
      # first of all: do we need authentication?
      path = String(req.route.path).replace( urlprefix, "")
      method = String(req.route.method).toLowerCase()
      if model.resources[ path ]?[method]?.authenticate? and model.resources[ path ][method]?.authenticate
        headervar = String( model.security.header_token ).toLowerCase()
        token = req.headers[ headervar ] || false
        # no token is no access
        return next( new Error("access denied (1)",1) ) if not token
        # if token doesnt match admin_token then no access
        if token == process.env.ADMIN_TOKEN
          lib.user = @.user = { is_god: true, token: token, name: "god" }
          return next() 
        # we got a a user from the db?
        if me.lib.extensions['coffeerest-api-db'].collections['user']?
          user = lib.extensions['coffeerest-api-db'].collections['user']
          user.find { apikey: token } 
          .populate('tags')
          .then (users) ->
            return next( new Error("access denied: invalid apikey",2) ) if not users[0]?
            # remember user + tags
            lib.user = @.user = users[0]
            rescol = @.db.url_to_resourcecollection path
            if not lib.user.can_access rescol.collection
              throw "user not tagged with 'can [create|read|update|delete] "+rescol.collection.identity+"'" 
            return next() # continue to next middleware
          .catch (err) -> next( new Error("access denied: "+err) ) 
        else
          return next new Error "access denied: no user" 
      else 
        next()

    me.db.events.addListener 'onResourceCall', (data, next) ->
      if me.user 
        if data.emitter and data.emitter.collections? # db extension?  
          db = data.emitter
          rescol = db.url_to_resourcecollection data.path
          if rescol.resource.schema.requiretag? and not (me.lib.user.is_god? and me.lib.user.is_god)
            mytags = me.lib.user.tags_flatten()
            for tag in rescol.resource.schema.requiretag
              continue if not tag.match(/^is/)
              if not mytags[tag]?
                return next( new Error("Sorry not allowed. You are not tagged with the privilege: '"+tag+"'" ) )
      next()

    me.db.events.addListener 'beforeSave', (data, next) ->
      console.log "save()"
      next()

    me.db.events.addListener 'beforeUpdate', (data, next) ->
      return next() if not me.security_enabled()
      me.user.strip_data data.data, data.collectionname, 'update'
      next()
    
    next()

  return @
