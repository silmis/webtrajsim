P = require 'bluebird'
$ = require 'jquery'
{Signal} = require './signal.ls'

export class WsController
	@Connect = (url) -> new P (resolve, reject) ->
		socket = new WebSocket url
		socket.onopen = ->
			resolve new WsController socket

	(@socket) ->
		@throttle = 0
		@brake = 0
		@steering = 0
		@direction = 1
		@change = new Signal
		@socket.onmessage = (msg) ~>
			event = JSON.parse msg.data
			for key, value of event
				@change.dispatch key, value
			@ <<< event

	set: (obj) ->
		@socket.send JSON.stringify obj

	close: ->
		@socket.onmessage = null
		@socket.close()

export class KeyboardController
	->
		@throttle = 0
		@brake = 0
		@steering = 0
		@direction = 1

		@throttleTarget = 0
		@brakeTarget = 0
		@steeringLeft = 0
		@steeringRight = 0

		@up = 0
		@down = 0
		@left = 0
		@right = 0

		changeSpeed = 2

		nudge = (dt, name, target) ~>
			return if not isFinite dt
			diff = target - @[name]
			change = dt*changeSpeed*Math.sign(diff)
			if diff < 0
				change = Math.max change, diff
			else
				change = Math.min change, diff
			@[name] += change

		@_closed = false
		prevTime = undefined
		tick = ~>
			return if @_closed
			time = Date.now()
			dt = (time - prevTime)/1000
			prevTime := time
			nudge dt, \throttle, @throttleTarget
			nudge dt, \brake, @brakeTarget
			nudge dt, \steering, (@steeringLeft - @steeringRight)
			requestAnimationFrame tick
		tick()
		@change = new Signal

		UP = 38
		DOWN = 40
		SPACE = 32
		LEFT = 37
		RIGHT = 39
		CTRL = 17

		$("body")
		.keydown @_keydown = (e) ~>
			switch e.which
			| UP => @throttleTarget = 1 ; @_update 'up', 1
			| DOWN => @brakeTarget = 1 ; @_update 'down', 1
			| LEFT => @steeringLeft = 1; @_update 'left', 1
			| RIGHT => @steeringRight = 1; @_update 'right', 1
			| CTRL => @_update \blinder, true
			| SPACE => @_update \catch, true

		.keyup @_keyup = (e) ~>
			switch e.which
			| UP => @throttleTarget = 0 ; @_update 'up', 0
			| DOWN => @brakeTarget = 0 ; @_update 'down', 0
			| LEFT => @steeringLeft = 0 ; @_update 'left', 0
			| RIGHT => @steeringRight = 0 ; @_update 'right', 0
			| CTRL => @_update \blinder, false
			| SPACE => @_update \catch, false



	_update: (key, value) ->
		return if @[key] == value
		@change.dispatch key, value
		@[key] = value

	set: ->

	close: ->
		@_closed = true
		$("body")
		.off "keydown", @_keydown
		.off "keyup", @_keyup

export NonSteeringControl = (orig) ->
	ctrl = ^^orig
	ctrl.steering = 0
	return ctrl

# OMG! https://code.google.com/p/v8/issues/detail?id=3495
tanh = (x) ->
	r = Math.tanh x
	if r != r
		return Math.sign x
	return r

export class TargetSpeedController2
	(@target=0) ->
		@throttle = 0
		@brake = 0
		@steering = 0
		@direction = 1
		@accel_multiplier = 1.0
		@brake_multiplier = 0.2
		@_accel = 0
		@_speed = 0
		@_force = 0

	tick: (speed, dt) ->
		@_accel = (@_speed - speed)/dt
		@_speed = speed

		target = @target * 1.01754859 # wind resistance	
		speedDelta = target - speed

		if target == 0 and speedDelta < 0.1 # stopping hack
			@_force = -0.5
		else
			if speedDelta > 0
				targetAccel = speedDelta * @accel_multiplier
			else
				targetAccel = speedDelta * @brake_multiplier
			@_force = tanh targetAccel
			#@_force = tanh (targetAccel - @_accel) * 0.1
				
		@_force = Math.max @_force, -1
		@_force = Math.min @_force, 1
		if @_force > 0
			@throttle = @_force
			@brake = 0
		else
			@brake = -@_force
			@throttle = 0

		#console.log 'speed', @_speed
		#console.log 'target', @target
		#console.log 'delta', delta
		#console.log 'force', @_force

	set: ->

export class TargetSpeedController
	(@target=0) ->
		@throttle = 0
		@brake = 0
		@steering = 0
		@direction = 1

	tick: (speed, dt) ->
		delta = @target - speed
		force = Math.tanh delta
		if force > 0
			@throttle = force
			@brake = 0
		else
			@brake = -force
			@throttle = 0

		console.log 'speed', speed
		console.log 'target', @target
		console.log 'delta', delta
		console.log 'force', force

	set: ->
