Unfancy rest apis, user permissions using tags on collections(fields) and api-token for coffeerest-api-db

<img alt="" src="https://github.com/coderofsalvation/coffeerest-api/raw/master/coffeerest.png" width="20%" />

* Limit users doing CRUD on collection- or fieldlevel
* Authenticate users before they can access certain data
* Activity based control (human readable) to collections (and fields)

## Activity based control using Tags?

Yes, suppose you have a collection 'user'.
When this user is tagged with 'is admin', 'can update user', and 'cannot update user email'.
Automatically, this module will recognize, based on the user (using apitoken), whether those permissions apply or not.
 
## Ouch! Is it that simple?

Just add these fields to your coffeerest-api `model.coffee` specification 

        {
        ...

    ->   security:
    ->     header_token: "X-FOO-TOKEN"

          db: 
            ...
            resources:
    ->        user:
    ->          connection: 'memory'
    ->          schema:
    ->            authenticate: true
    ->            taggable: true
    ->            description: "author"
    ->            requiretag: ["is user","can update user","cannot update user email"]
    ->            required: ['email','apikey']
    ->            payload:
    ->              email:   { type: "string", default: 'John Doe', pattern: "[@\.]" }
    ->              apikey:  { type: "string", default: "john@doe.com", index:true }

              article:
                connection: 'memory'
                schema:
                  authenticate: true
                  description: "this foo bar"
    ->            # this restricts access to article collection + restrict updating 'content field'
    ->            requiretag: ["is user","cannot update article content"]      
                  taggable: true
                  owner: "user"
                  required: ['title','content']
                  payload:
                    title: 
                      type: "string"
                      default: "title not set"
                      minLength: 2
                      maxLength: 40
                      index: true
                    content:
                      type: "string"
                      default: "Lorem ipsum"
                    date:
                      type: "string"
                      default: "2012-02-02"


## Usage 

    npm install coffeerest-api
    npm install coffeerest-api-db
    npm install coffeerest-api-db-permissions


for more info / servercode see [coffeerest-api](https://www.npmjs.com/package/coffeerest-api)

## Example 

Permissions are set using the `tag`-feature of `coffeerest-api-db`-extension.
So in order for the user to get access to the article-collection above, tag the user first:

    # set an admin token to bypass security
    $ export ADMIN_TOKEN=foobar
    $ coffee server.coffee

    ## add user
    curl -H X-FOO-TOKEN: foobar -X POST http://localhost:4455/v1/user --data {"email":"foo@hotmail.com","apikey":"FLOPFLAP"}

    # add tags (global)
    curl -H X-FOO-TOKEN: foobar -X POST http://localhost:4455/v1/user/tag --data {"name":"is user"}
    curl -H X-FOO-TOKEN: foobar -X POST http://localhost:4455/v1/user/tag --data {"name":"is admin user"}
    curl -H X-FOO-TOKEN: foobar -X POST http://localhost:4455/v1/user/tag --data {"name":"is editor","subtags":["can create,read,update,delete article","cannot create,read,update user email"]}

    # add tag 'is user' (id 1) and 'cannot update article content' (id 2) to userid 1
    curl -H X-FOO-TOKEN: foobar -X GET http://localhost:4455/v1/user/tag/1/1/enable
    curl -H X-FOO-TOKEN: foobar -X GET http://localhost:4455/v1/user/tag/1/3/enable

    # now user (with apitoken of userid 1) can access articles
    curl -H X-FOO-TOKEN: FLOPFLAP -X GET http://localhost:4455/v1/article/123 

