do ->
  "use strict"
  isTouch = "ontouchstart" of window

  unless Backbone
    console?.error "Ensure Backbone is included before backbone.viewstack"

  ease = (time, intensity = 2) ->
    if time is 0
      return 0
    else if time is 1
      return 1
    else if (time = time/(0.5)) < 1
      return 0.5 * Math.pow(2, intensity*(time-1))
    else
      0.5*(-Math.pow(2,-intensity*(time-1))+2)

  class Backbone.ViewStack extends Backbone.View

    defaults:
      viewPath: "views/"
      headClass: ".view-head"
      bodyClass: ".view-body"
      ms: 300
      overwrite: true
      slideStartPosition: 40
      slideCompletionRatio: 0.5

    el: "#views"

    # A dictionary of all views that have been created.
    views: {}

    # An array of views in the current stack from bottom to top.
    stack: []

    # On the first run, we prevent the push mechanic from causing a transition.
    # This is later used to prevent pushes when manually swiping.
    preventTransition: true

    # Remember when we fade in views, so we can fade them out.
    willCustomPush: false

    initialize: (options) ->
      for key, val of _.extend({}, @defaults, options)
        @[key] = val

      console?.error "Declare viewpath for views" unless @viewPath

      @$el.html("") if @overwrite

      return this

    # Split camel-cased names, transform to lower case and replace slashes.
    # eg. ProductTable becomes product-table-view
    # eg. Item/Detail becomes item-detail-view
    identify: (string) ->
      string
        .replace(/([a-z])([A-Z])/g, "$1-$2")
        .toLowerCase()
        .replace(/\//g,"-") + "-view"

    # If no `el` is defined in options, create a new element and append to the
    # `#views` element. Create the view, hide it and add it to the stack.
    create: (name, View, options = {}) ->
      key = options.key or name

      unless options.el?
        options.el = $("<div class='view' id='#{@identify(key)}' />")
        @$el.append options.el

      view = new View(options)
      view.__key = key
      view.__head = view.$(@headClass)
      view.__body = view.$(@bodyClass)

      view.open ?= (options) => @openView(view, options)
      view.exit ?= => @exitView(view)

      view.$el.hide()
      @views[key] = view

    # Open a new view from a child view
    openView: (view, options) ->
      @show(view.__key, options)

    # Exit a view from a child view if the stack is big enough and it is at
    # the top of the stack
    exitView: (view) ->
      if @stack.length > 1 and @stack[@stack.length - 1].__key is view.__key
        if @isLinear
          window.history.back()
        else
          @show(@stack[@stack.length - 2].__key)

    getCurrentView: ->
      _.last(@stack)

    # Get the view from the dictionary, or create it if it doesn't exist.
    # Decide whether to pop or push the view, and build the stack if its the
    # first run and a stack is declared on the new view being created.
    # If we are popping and there are no views in the stack,
    # add the current view. This occurs when we refresh the browser on a view
    # part way down the stack.
    show: (name, options = {}) ->
      key = options.key or name
      prevView = @stack[@stack.length - 1]

      if @views[key]?
        nextView = @views[key]
      else
        viewClass = require @viewPath + name
        nextView = @create name, viewClass, options
        if @stack.length is 0 and nextView.stack
          for _name, i in nextView.stack when _name isnt name
            viewClass = require @viewPath + _name
            view = @create _name, viewClass
            view.$el.css zIndex: i + 1
            @stack.push view

      # Only go to the trouble if this view isn't already active
      if not prevView or prevView.__key isnt key

        # Assume we're pushing if the new view is already in the stack.
        isPush = @stack.indexOf(nextView) < 0

        # We're popping if the previous view explicitly declares so.
        if prevView?.stack?.indexOf(name) > -1
          isPush = false
        nextView.show?(_.extend options, { isPush })

        if options.isDialog
          @willShowDialog = true

        # Custom transitions means we remove swiping.
        if options.transition
          @undelegateEvents()
        else
          @delegateEvents()

        # Set the transition to be used
        if options.transition
          @willCustomPush = true
          @transform = @["#{options.transition}Transform"]
        else if not @willCustomPush
          @willCustomPush = false
          @transform = @slideTransform

        if isPush or @stack.length is 0 and not @preventTransition
          @pushView(nextView)

        else
          if @willShowDialog
            prevView = @removeDialog(nextView) or prevView

          @stack =
            @stack.slice(0, @stack.indexOf(nextView) + 1).concat(prevView)

          # Ensure the view we pop to is underneath in the stack
          @stack.unshift(nextView) if @stack.length is 1
          @popView()
          @willHideDialog = false
          @willCustomPush = false unless options.transition

        @trigger("show", nextView, options)

    # Get the last view in the stack, push the new view and activate it.
    pushView: (view) ->
      prevView = @stack[@stack.length - 1]
      @stack.push(view)
      @activateCurrentView(prevView, true)

    # Pop the last view off the stack and activate it.
    popView: ->
      @activateCurrentView(@stack.pop(), false)

    # If we have to remove the dialog, we pop as normal set willHideDialog to
    # true. However, if we route to another view (not the last) we use a normal
    # transform and remove the dialog immediately.
    removeDialog: (nextView) ->
      @willShowDialog = false

      if @stack.indexOf(nextView) is @stack.length - 2
        @willHideDialog = true
        return
      else
        @transform @stack.pop().undelegateEvents(), 1, true
        @transform = @slideTransform
        return @stack[@stack.length - 1]

    # Perform two transitions synchronously. Get the next view, and get it
    # ready to animate. Remove events from the old view.
    activateCurrentView: (prevView, isPush) ->
      nextView = @stack[@stack.length - 1]

      @cleanup(nextView.$el) unless @willShowDialog

      if @preventTransition
        nextView.delegateEvents().$el.show().addClass("active")
        prevView?.$el.hide()
        @preventTransition = false

      else if prevView isnt nextView
        prevView.undelegateEvents().hide?()

        # Set appropriate z-index
        prevView.$el.css(zIndex: @stack.length + (if isPush then -1 else 1))
        nextView.$el.css(zIndex: @stack.length)

        # Show the next view
        nextView.$el.show().addClass("active")

        # Remove transitions before setting initial transforms...
        @transitionView nextView, false
        @transitionView prevView, false

        # ... and then set initial transforms
        @transform prevView, 0, not isPush unless @willShowDialog

        unless @willHideDialog
          @transform nextView, @endRatio(isPush), isPush

        @$el.get(0).offsetWidth

        # Add transitions and set new transforms
        @transitionView nextView, true
        @transform nextView, 0, not isPush

        unless @willShowDialog
          @transitionView prevView, true
          @transform prevView, @endRatio(not isPush), not isPush

        # After the transition has occured, hide
        window.clearTimeout @transitionOutTimeout
        @transitionOutTimeout = window.setTimeout (=>
          nextView.delegateEvents()
          prevView.$el.removeClass("active")
          prevView.$el.hide() unless @willShowDialog
          @clearTransforms nextView
          @clearTransforms prevView
        ), @ms + 100

    # Cleanup views if navigating very quickly without harming transitions.
    # These views have already had their events undelegated, so we just need
    # to hide them and remove their active class.
    cleanup: ($el) ->
      window.clearTimeout @cleanupTimeout
      @cleanupTimeout = window.setTimeout (=>
        if $el.hasClass("active") and not @slide
          @$(".view").not($el).hide().removeClass("active")
          $el.show().addClass("active")
      ), @ms

    # The ratio at the end of a transtion.
    # When popping, views only move halfway back.
    endRatio: (isPush) ->
      if isPush then 1 else -0.5

    # Touch events for navigation interaction
    events: ->
      events = {}
      events[if isTouch then "touchstart" else "mousedown"] = "onStart"
      events[if isTouch then "touchmove" else "mousemove"] = "onMove"
      events[if isTouch then "touchend" else "mouseup"] = "onEnd"
      events["touchcancel"] = "onEnd" if isTouch

      return events

    # When we slide from within the `slideStartPosition`, we start the
    # view transitions if the stack contains enough views. We stop any CSS
    # transitions on the two views, and ensure that they are visible. We'll
    # also treat the first touch as a move event to start the transitions.
    # Use @preventPop to stop the view from popping.
    onStart: (e) ->
      prevView = @stack[@stack.length - 1]
      inPrevStack = prevView.stack?.indexOf(prevView.__key) > 0

      return if (@stack.length < 2 and not inPrevStack) or
                e.target.nodeName.match(/INPUT|TEXTAREA/) or
                @stack.slice(-1)[0].preventPop is true

      _e = if isTouch then e.touches[0] else e

      @offset ?= @$el.offset()

      if _e.pageX - @offset.left < @slideStartPosition
        if inPrevStack
          index = prevView.stack.indexOf(prevView.__key) - 1
          nextView = @views[prevView.stack[index]]
        else
          nextView = @stack[@stack.length - 2]

        prevView.$el.css zIndex: @stack.length
        nextView.$el.css zIndex: @stack.length - 1

        @slide =
          startX: _e.pageX - @offset.left
          startY: _e.pageY
          prev: prevView
          next: nextView
          hasSlid: false

        @onMove(e)

    # If the slide object exists, calculate the ratio (between 0 and 1) of how
    # far we have moved, and transform the views accordingly. Ensure that we
    # don't slide outside of the bounds. Don't listen anymore when we've gone
    # over 20 pixels vertically.
    onMove: (e) ->
      return if not @slide?

      e.preventDefault() if e.type is "touchmove"

      _e = if isTouch then e.touches[0] else e

      if not @slide.hasSlid
        if Math.abs(_e.pageX - @offset.left - @slide.startX) > 10
          window.clearTimeout @transitionOutTimeout
          @slide.hasSlid = true
          @slide.prev.undelegateEvents()
          @slide.next.undelegateEvents()
          @transitionView @slide.prev, false
          @transitionView @slide.next, false
          @transform = @slideTransform
          @slide.next.$el.show()
          @slide.prev.$el.show()
          @trigger("slidestart")

        else if Math.abs(_e.pageY - @slide.startY) > 20
          return @onEnd()

      if @slide.hasSlid
        e.stopPropagation()

        @slide.ratio =
          Math.min(Math.max(
            (_e.pageX - @offset.left - @slide.startX) / @offset.width
          , 0), 1)

        @transform(@slide.prev, @slide.ratio, true)
        @transform(@slide.next, -(1 - @slide.ratio) * 0.5, false)

    # If the slide object exists, remove the transition styles from the current
    # views. We'll pop the current view if we've slid over half of the screen,
    # in which case we need to ensure that the history.back() pops, and the
    # view leaving has the correct classes. Otherwise, we'll make sure the
    # hidden view returns to its transition position and then clear it's
    # position after the transition duration has passed.
    onEnd: (e) ->
      return if not @slide?

      @transitionView @slide.prev, true
      @transitionView @slide.next, true

      if @slide.hasSlid
        e.stopPropagation()
        next = @slide.next
        prev = @slide.prev

        if @slide.ratio > @slideCompletionRatio
          @transform prev, @endRatio(true), true
          @transform next, 0, true
          @preventTransition = true
          @cleanup(@slide.next.$el)
          @undelegateEvents()

          window.clearTimeout @transitionEndTimeout
          @transitionEndTimeout = window.setTimeout (=>
            if @isLinear
              window.history.back()
              @delegateEvents()
            else
              @show(next.__key)
          ), @ms + 100
        else
          @transform prev, 0, false
          @transform next, @endRatio(false), false
          @cleanup(@slide.prev.$el)
          prev.delegateEvents()

        @trigger("slideend")

      @slide = null

    # Set the transition on the view's head and body.
    transitionView: (view, willTransition) ->
      transition = if willTransition then "all #{@ms}ms" else "none"

      view.__head.add(view.__body).css
        "-webkit-transition": transition
        "-moz-transition": transition
        "-ms-transition": transition
        "-o-transition": transition
        "transition": transition

    # Sliding affects the view in several ways. The ratio dictates its
    # position, but also opacity of the view's body if it is pushing, and the
    # view's head if it is popping.
    slideTransform: (view, ratio, isPush) ->
      if view
        transform = "translate3d(#{ratio * 100}%, 0, 0)"

        view.__body.css
          "-webkit-transform": transform
          "-moz-transform": transform
          "-ms-transform": transform
          "-o-transform": transform
          "transform": transform
          "opacity": if not isPush then 1 + ratio else 1

        view.__head.css
          "opacity": if isPush then 1 - ease(ratio, 8) else 1

    # Scale both views down, the view on top ending at 100%.
    zoomTransform: (view, ratio, isPush) ->
      if view
        transform = "translate3d(0, 0, 0) scale(#{1 + ratio * 0.25})"

        view.__body.css
          "-webkit-transform": transform
          "-moz-transform": transform
          "-ms-transform": transform
          "-o-transform": transform
          "transform": transform
          "opacity": if isPush then 1 - ease(ratio) else 1

        view.__head.css
          "opacity": if isPush then 1 - ease(ratio) else 1

    # Simply fade the new view in over the preceding view
    fadeTransform: (view, ratio, isPush) ->
      if view
        view.__body.css
          "opacity": if isPush then 1 - ease(ratio) else 1

        view.__head.css
          "opacity": if isPush then 1 - ease(ratio) else 1

    # Remove any transforms set during transitions
    clearTransforms: (view) ->
      if view
        view.__body.css
          "-webkit-transform": ""
          "-moz-transform": ""
          "-ms-transform": ""
          "-o-transform": ""
          "transform": ""
          "opacity": ""

        view.__head.css
          "opacity": ""
