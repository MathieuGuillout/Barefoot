Barefoot
========

Barefoot is a utility-belt library for Node for asynchronous functions manipulation

To install it

`npm install barefoot`

To use it

`bf = require 'barefoot'`

   
Module dependencies
-------------------


    lateral = require 'lateral'
    _       = require 'underscore'
    check   = require './check'



Let's get started
------------------

**ignore**

Create a function of form (arg, args...) from a function of form (args...).

    ignore = (func) ->
      (arg, args...) ->
        func args...

**errorWrapper**

    errorWrapper = (handler) ->
      (func) ->
        (err, args...) ->
          if err?
            handler err
          else
            func args...

**sequence**

    sequence = (done) ->
      queue = []
      running = false
      finished = false
      result = null

      run = ->
        running = true

        if queue.length > 0
          func = queue[0]
          queue = queue[1..]

          func result, (err, res) ->
            if err?
              done err
            else
              result = res
              run()
        else
          running = false
          if finished
            done null, result

      add: (func) ->
        queue.push func
        if not running then run()

      then: (func) ->
        queue.push ignore func
        if not running then run()

      end: ->
        finished = true
        if not running then run()

      w: errorWrapper done

**validate**

    validate = (schema) ->
      (params, done) ->
        ok = check params, schema
        if ok
          done null, params
        else
          done HttpError.badRequest(), params


**toDictionary** 

Transform an array of object into a dictionary based on the property passed as a second param

    toDictionary = (array, prop) ->
      dictionary = {}
      array.forEach (elt) -> 
        dictionary[elt[prop]] = elt if elt? and elt[prop]?
      return dictionary



**has**

Provides a function which test if parameters object has certain properties

    has = (parameters) ->
      (params, done) ->
        ok = true
        ok = (ok and params? and params[par]?) for par in parameters
        done (if ok then null else new Error("Missing Parameters")), params


**amap**

Asynchronous map 
Use the awesome **lateral** module to do the job

    amap = (func, nbProcesses = 1) ->
      (array, done) ->
        results = []
        errors = null
        unit = lateral.create (complete, item) ->
          func item, (err, res) ->
            if err?
              errors ?= []
              errors.push(err)
              results.push null
            else
              results.push res
            complete()
        , nbProcesses

        unit.add(array).when () ->
          done errors, results

**chain**

Chain aynschronous methods with signature (val, done) -> done(err, result)
Stop if one of the method has an error in the callback

    chain = (funcs) ->
      (val, done) ->
        if funcs.length == 0
          done null, val
        else
          funcs[0] val, (err, res) =>
            if err?
              done err, res
            else
              chain(funcs[1..])(res, done)

**select**

    select = (func) ->
      (params, done) ->
        done null, func(params)

**avoid**

Wrap a void returning function to make it callable in a chain

    avoid = (func) ->
      (params, done) ->
        func(params)
        done null, params 


**parallel**

Execute asynchronous functions which take same inputs 

    parallel = (funcs) ->
      (params, done) -> 
        
        i = 0
        errors = []
        results = []
        tempDone = (err, result) ->
          i++
          errors.push(err) if err?
          results.push result
          if i == funcs.length
            error = if errors.length > 0  then errors else null
            done error, results

        funcs.forEach (func) ->
          func params, tempDone


**getRequestParams**

    getRequestParams = (req) -> 
      params = {}
      for field in ["body", "query", "params"]
        if req[field]?
          params = _.extend params, req[field]
      params.user = req.user if req.user?
      params


**webService**

    webService = (method, contentType = "application/json") ->
      (req, res) ->
        method getRequestParams(req), (err, data) ->
          if err?
            console.error err
            if err instanceof HttpError
              err.apply res
            else
              res.send 500
          else
            if contentType == "application/json"
              res.send data
            else
              res.contentType contentType
              res.end data.toString()

**webPage**

    webPage = (template, method) ->
      (req, res) ->
        if not method? and template?
          data = getRequestParams(req)
          data.__ = 
            template : template
          res.render template, data 
        else
          method getRequestParams(req), (err, data) ->
            if err?
              if err instanceof HttpError
                err.apply res
              else
                console.error err
                res.send 500
            else
              data = {} if not data?
              data.user = req.user if req.user? and not data.user?
              data.__ = 
                template : template
              res.render template, data

**middleware**

    middleware = (func) ->
      (req, res, ok) ->
        func req, (err, val) ->
          if err?
            if err instanceof bf.HttpError
              bf.apply res
            else
              console.error err
              res.send 500
          else
            ok()

**memoryCache**
    

    memoize = (method, seconds) ->
      cache = {}

      (params, done) ->
        hash = JSON.stringify(params)
        if cache[hash]? and cache[hash].expiration > new Date()
          done null, cache[hash].result
        else
          method params, (err, res) ->
            if not err?
              cache[hash] =
                result : res
                expiration : (new Date()).setSeconds((new Date()).getSeconds() + seconds)

            done err, res

**HttpError**

When `webService` or `webPage` gets an instance of HttpError back as an error (in the callback), a custom
HTTP response code and message can be used.

    class HttpError
      # static helper methods
      @badRequest          = -> new @ code: 400
      @unauthorized        = -> new @ code: 401
      @forbidden           = -> new @ code: 403
      @notFound            = -> new @ code: 404
      @internalServerError = -> new @ code: 500

      code: 500
      data: null
      headers: null

      constructor: (params) ->
        {@code, @data, @headers} = params

      apply: (res) ->
        for key, value of @headers
          res.set key, value
        res.send @code, @data


Export public methods
---------------------

    module.exports =
      toDictionary : toDictionary
      has          : has
      amap         : amap
      chain        : chain
      avoid        : avoid
      select       : select
      parallel     : parallel
      webService   : webService
      webPage      : webPage
      memoize      : memoize
      HttpError    : HttpError
      check        : check
      sequence     : sequence
      ignore       : ignore
      errorWrapper : errorWrapper
      validate     : validate


