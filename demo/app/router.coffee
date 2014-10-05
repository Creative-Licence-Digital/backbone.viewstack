class AppRouter extends Backbone.Router

  initialize: (callback) ->
    @viewstack = new Backbone.ViewStack(viewPath: "views/", el: "#views")
    callback()

  routes:
    "level1":       "level1"
    "level2":       "level2"
    "level3":       "level3"

    "*default":     "level1"

  level1: ->
    @viewstack.show "level1"

  level2: ->
    @viewstack.show "level2"

  level3: ->
    @viewstack.show "level3"


module.exports = AppRouter