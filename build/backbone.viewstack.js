/* backbone.viewstack - v0.0.1 - MIT */
/* Manage views & transitions without the boilerplate */
/* https://github.com/Creative-Licence-Digital/backbone.viewstack */
var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

(function() {
  "use strict";
  var isTouch;
  isTouch = "ontouchstart" in window;
  if (!Backbone) {
    if (typeof console !== "undefined" && console !== null) {
      console.error("Ensure Backbone is included before backbone.viewstack");
    }
  }
  return Backbone.ViewStack = (function(_super) {
    __extends(ViewStack, _super);

    function ViewStack() {
      this.create = __bind(this.create, this);
      return ViewStack.__super__.constructor.apply(this, arguments);
    }

    ViewStack.prototype.el = "#views";

    ViewStack.prototype.views = {};

    ViewStack.prototype.stack = [];

    ViewStack.prototype.preventPush = true;

    ViewStack.prototype.initialize = function(options) {
      if (!options.viewPath) {
        if (typeof console !== "undefined" && console !== null) {
          console.error("Declare viewpath for views");
        }
      }
      this.viewPath = options.viewPath;
      this.headClass = options.headClass || ".view-head";
      this.bodyClass = options.bodyClass || ".view-body";
      return this;
    };

    ViewStack.prototype.identify = function(string) {
      return string.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase().replace(/\//g, "-") + "-view";
    };

    ViewStack.prototype.create = function(name, View, options) {
      var view;
      if (options == null) {
        options = {};
      }
      if (options.el == null) {
        options.el = $("<div class='view' id='" + (this.identify(name)) + "' />");
        this.$el.append(options.el);
      }
      view = new View(options);
      view.$el.hide();
      return this.views[name] = view;
    };

    ViewStack.prototype.show = function(name, options) {
      var i, key, nextView, prevView, push, view, viewClass, _i, _len, _name, _ref, _ref1;
      if (options == null) {
        options = {};
      }
      key = options.key;
      if (key == null) {
        key = name;
      }
      if (this.views[key] != null) {
        nextView = this.views[key];
      } else {
        viewClass = require(this.viewPath + name);
        nextView = this.create(name, viewClass, options);
        if (this.stack.length === 0 && nextView.stack) {
          _ref = nextView.stack;
          for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
            _name = _ref[i];
            if (!(_name !== name)) {
              continue;
            }
            viewClass = require(this.viewPath + _name);
            view = this.create(_name, viewClass);
            view.$el.css({
              zIndex: i + 1
            });
            this.stack.push(view);
          }
        }
      }
      if (typeof nextView.show === "function") {
        nextView.show(options);
      }
      prevView = this.stack.slice(-1)[0];
      push = this.stack.indexOf(nextView) < 0;
      if ((prevView != null ? (_ref1 = prevView.stack) != null ? _ref1.indexOf(name) : void 0 : void 0) > -1) {
        push = false;
      }
      if ((push && !this.preventPush) || this.stack.length === 0) {
        return this.pushView(nextView);
      } else {
        this.stack = this.stack.slice(0, this.stack.indexOf(nextView) + 1).concat(prevView);
        if (this.stack.length === 1) {
          this.stack.unshift(nextView);
        }
        return this.popView();
      }
    };

    ViewStack.prototype.pushView = function(view) {
      var prevView;
      prevView = this.stack.slice(-1)[0];
      this.stack.push(view);
      return this.activateCurrentView(prevView, true);
    };

    ViewStack.prototype.popView = function() {
      return this.activateCurrentView(this.stack.pop(), false);
    };

    ViewStack.prototype.activateCurrentView = function(prevView, isPush) {
      var nextView, _base;
      nextView = this.stack.slice(-1)[0];
      if (this.preventPush) {
        nextView.delegateEvents().$el.show();
        if (prevView != null) {
          prevView.$el.hide();
        }
        return this.preventPush = false;
      } else if (prevView !== nextView) {
        if (typeof (_base = prevView.undelegateEvents()).hide === "function") {
          _base.hide();
        }
        prevView.$el.css({
          zIndex: this.stack.length + (isPush ? -1 : 1)
        });
        nextView.$el.css({
          zIndex: this.stack.length
        });
        nextView.$el.show().addClass("active");
        this.transitionView({
          view: nextView
        }, false);
        this.transitionView({
          view: prevView
        }, false);
        this.transformView({
          view: prevView
        }, 0, !isPush);
        this.transformView({
          view: nextView
        }, this.endRatio(isPush), isPush);
        window.clearTimeout(this.transitionInTimeout);
        return this.transitionInTimeout = window.setTimeout(((function(_this) {
          return function() {
            _this.transitionView({
              view: nextView
            }, true);
            _this.transitionView({
              view: prevView
            }, true);
            _this.transformView({
              view: nextView
            }, 0, !isPush);
            _this.transformView({
              view: prevView
            }, _this.endRatio(!isPush), !isPush);
            window.clearTimeout(_this.transitionOutTimeout);
            return _this.transitionOutTimeout = window.setTimeout((function() {
              nextView.delegateEvents();
              return prevView.$el.hide().removeClass("active");
            }), 300);
          };
        })(this)), 10);
      }
    };

    ViewStack.prototype.endRatio = function(isPush) {
      if (isPush) {
        return 1;
      } else {
        return -0.5;
      }
    };

    ViewStack.prototype.events = function() {
      var events;
      events = {};
      events[isTouch ? "touchstart" : "mousedown"] = "onStart";
      events[isTouch ? "touchmove" : "mousemove"] = "onMove";
      events[isTouch ? "touchend" : "mouseup"] = "onEnd";
      events[isTouch ? "touchcancel" : "mouseleave"] = "onEnd";
      return events;
    };

    ViewStack.prototype.onStart = function(e) {
      var nextView, offset, prevView, _e;
      if (this.stack.length < 2 || e.target.nodeName.match(/INPUT|TEXTAREA/)) {
        return;
      }
      _e = isTouch ? e.touches[0] : e;
      offset = this.$el.offset();
      this.hasSlid = false;
      if (_e.pageX - offset.left < 40 && this.stack.length > 1) {
        prevView = this.stack.slice(-1)[0];
        nextView = this.stack.slice(-2, -1)[0];
        this.slide = {
          startX: _e.pageX - offset.left,
          startY: _e.pageY,
          offset: offset,
          prev: {
            view: prevView,
            viewHead: prevView.$(this.headClass),
            viewBody: prevView.$(this.bodyClass)
          },
          next: {
            view: nextView,
            viewHead: nextView.$(this.headClass),
            viewBody: nextView.$(this.bodyClass)
          }
        };
        return this.onMove(e);
      }
    };

    ViewStack.prototype.onMove = function(e) {
      var _e;
      if ((this.slide == null) || this.stack.length < 2) {
        return;
      }
      if (e.type === "touchmove") {
        e.preventDefault();
      }
      _e = isTouch ? e.touches[0] : e;
      if (!this.hasSlid) {
        if (Math.abs(_e.pageX - this.slide.offset.left - this.slide.startX) > 10) {
          this.hasSlid = true;
          this.slide.prev.view.undelegateEvents();
          this.slide.next.view.undelegateEvents();
          this.transitionView(this.slide.prev, false);
          this.transitionView(this.slide.next, false);
          this.slide.next.view.$el.show();
          this.slide.prev.view.$el.show();
        } else if (Math.abs(_e.pageY - this.slide.startY) > 20) {
          this.onEnd();
        }
      }
      if (this.hasSlid) {
        e.stopPropagation();
        this.slide.ratio = Math.min(Math.max((_e.pageX - this.slide.offset.left - this.slide.startX) / this.slide.offset.width, 0), 1);
        this.transformView(this.slide.prev, this.slide.ratio, true);
        return this.transformView(this.slide.next, -(1 - this.slide.ratio) * 0.5, false);
      }
    };

    ViewStack.prototype.onEnd = function(e) {
      var next, prev;
      if ((this.slide == null) || this.stack.length < 2) {
        return;
      }
      this.transitionView(this.slide.prev, true);
      this.transitionView(this.slide.next, true);
      if (this.hasSlid) {
        e.stopPropagation();
        next = this.slide.next;
        prev = this.slide.prev;
        if (this.slide.ratio > 0.5) {
          this.transformView(prev, this.endRatio(true), true);
          this.transformView(next, 0, true);
          this.preventPush = true;
          window.clearTimeout(this.transitionEndTimeout);
          this.transitionEndTimeout = window.setTimeout(((function(_this) {
            return function() {
              return window.history.back();
            };
          })(this)), 400);
        } else {
          this.transformView(prev, 0, false);
          this.transformView(next, this.endRatio(false), false);
          prev.view.delegateEvents();
        }
      }
      return this.slide = null;
    };

    ViewStack.prototype.transitionView = function(_arg, willTransition) {
      var transition, view, viewBody, viewHead;
      view = _arg.view, viewHead = _arg.viewHead, viewBody = _arg.viewBody;
      transition = willTransition ? "all 300ms" : "none";
      return (viewBody || view.$(this.bodyClass)).add(viewHead || view.$(this.headClass)).css({
        "-webkit-transition": transition,
        "-moz-transition": transition,
        "-ms-transition": transition,
        "-o-transition": transition,
        "transition": transition
      });
    };

    ViewStack.prototype.transformView = function(_arg, ratio, isPush) {
      var transform, view, viewBody, viewHead;
      view = _arg.view, viewHead = _arg.viewHead, viewBody = _arg.viewBody;
      if (view) {
        transform = "translate3d(" + (ratio * 100) + "%, 0, 0)";
        (viewBody || view.$(this.bodyClass)).css({
          "-webkit-transform": transform,
          "-moz-transform": transform,
          "-ms-transform": transform,
          "-o-transform": transform,
          "transform": transform,
          "opacity": !isPush ? 1 + ratio : 1
        });
        return (viewHead || view.$(this.headClass)).css({
          "opacity": isPush ? 1 - ratio : 1
        });
      }
    };

    return ViewStack;

  })(Backbone.View);
})();