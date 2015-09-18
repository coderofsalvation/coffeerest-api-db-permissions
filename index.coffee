JSVD = require('./../coffeerest-api/node_modules/json-schema-defaults')

module.exports = (server,model,lib, urlprefix) ->

  me = @
  @.db  = false
  @.lib = lib
  @.user = false 
  @.model = model

  console.log "setting up user & data security"

  @.check_collection_permissions = ( data, type ) ->
    user = me.user 
    return if not data.collectionname? or not user.tags?
    collection = @.db.collections[ data.collectionname ]
    aclstr = "can "+type+" "+data.collectionname
    aclstrings = {}
    aclstrings[aclstr] = true 
    for tag in user.tags
      console.log tag.name
      continue if not tag.name.match(/^cannot/)
      tagparts = tag.name.split(' ')
      continue if not tagparts.length == 4 
      allowed    = tagparts[0]
      operations = tagparts[1].split(',')
      cname      = tagparts[2] 
      field      = tagparts[3]
      aclstrings[allowed+" "+operation+" "+cname+" "+tagparts[3] ] = true
    console.dir aclstrings
    #aclstrings_user = []
    #for tag,tv of user.tags
    #  console.log "hoi"
    #  #continue if not tag.match(/^can/)
    #  tagparts = tag.split(' ')
    #  allowed    = ( tagparts[0] == 'can' )
    #  operations = tagparts[1].split(',')
    #  cname      = tagparts[2] 
    #  field      = tagparts[3]
    #  aclstrings_user.push "can "+operation+" "+cname+" "+field 
    #for k,v of data
    #  continue if String(k).match(/id$/) or k == "tags"
    #  aclstrings.push "cannot "+type+" "+collectionname+" "+k
    #console.dir aclstrings
    #console.dir aclstrings_user
    #  #if field == k
    #  #  console.log "jaaa: "+k 
    #  #  for tag,tv of @.user.tags
    #  #    continue if not tag.match(/^can/)
    #  #    tagparts = tag.split(' ')
    #  #    console.dir tagparts
    #  #    allowed    = ( tagparts[0] == 'can' )
    #  #    operations = tagparts[1].split(',')
    #  #    cname      = tagparts[2] 
    #  #    field      = tagparts[3]
    #  #    if collectionname == cname and type in operations
    #  #      console.log tag
    #  #      for k,v in data
    #  #        if field == k
    #  #          console.log "jaaa: "+k 

  # on each rest request, check if user has permissions 
  # to collection(fields) based on requiretag-keys set on resource schemaconfig
  server.on 'request', (request, res, cb) ->
    if not me.db
      me.db = me.lib.extensions['coffeerest-api-db']

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
            lib.user = @.user = { is_god: true }
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
              next() # continue to next middleware
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
            if rescol.resource.schema.requiretag? and not (me.user.is_god? and me.user.is_god)
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
        next() if me.user.is_god? and me.user.is_god
        err = me.check_collection_permissions data, 'update'
        return next() #if err then next(err) else next()

  return true
