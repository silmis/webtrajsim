P = require 'bluebird'
Co = P.coroutine
$ = require 'jquery'
seqr = require './seqr.ls'

{addGround, Scene} = require './scene.ls'
{addVehicle} = require './vehicle.ls'
{NonSteeringControl} = require './controls.ls'
{DefaultEngineSound} = require './sounds.ls'
assets = require './assets.ls'

ui = require './ui.ls'

exportScenario = (name, impl) ->
	scn = seqr.bind impl
	scn.scenarioName = name
	module.exports[name] = scn
	return scn

DummyScene = ->
	beforePhysics: Signal!
	afterPhysics: Signal!
	beforeRender: Signal!
	onRender: Signal!
	onStart: Signal!
	onExit: Signal!
	onTickHandled: Signal!
	#camera: new THREE.PerspectiveCamera!
	camera:
		updateProjectionMatrix: ->
		add: ->
	#visual: new THREE.Scene!
	visual:
		add: ->
		traverse: ->
		addEventListener: ->
	physics:
		add: ->
		addEventListener: ->
		removeBody: ->
	preroll: ->
	tick: ->
	bindPhys: ->
#Scene = DummyScene

export baseScene = seqr.bind (env) ->*
	{controls, audioContext, L} = env
	scene = new Scene
	yield P.resolve addGround scene
	sky = yield P.resolve assets.addSky scene

	scene.playerControls = controls

	player = yield addVehicle scene, controls, objectName: 'player'
	player.eye.add scene.camera
	player.physical.position.x = -1.75
	scene.player = player

	scene.player.speedometer = ui.gauge env,
		name: L "Speed"
		unit: L "km/h"
		value: ->
			speed = scene.player.getSpeed()*3.6
			Math.round speed

	engineSounds = yield DefaultEngineSound audioContext
	gainNode = audioContext.createGain()
	gainNode.connect audioContext.destination
	engineSounds.connect gainNode
	scene.afterPhysics.add ->
		rev = Math.abs(player.getSpeed())/(200/3.6)
		rev = Math.max 0.1, rev
		rev = (rev + 0.1)/1.1
		gain = scene.playerControls.throttle
		gain = (gain + 0.5)/1.5
		gainNode.gain.value = gain
		engineSounds.setPitch rev*2000
	scene.onStart.add engineSounds.start
	scene.onExit.add engineSounds.stop

	scene.preroll = ->
		# Tick a couple of frames for the physics to settle
		scene.tick 1/60
		n = 100
		t = Date.now()
		for [0 to n]
			scene.tick 1/60
		console.log "Prewarming FPS", (n/(Date.now() - t)*1000)
	return scene

export minimalScenario = seqr.bind (env) ->*
	scene = new Scene
	addGround scene
	scene.preroll = ->
	@let \scene, scene
	yield @get \done

exportScenario \freeDriving, (env) ->*
	# Load the base scene
	scene = yield baseScene env

	# The scene would be customized here

	# "Return" the scene to the caller, so they know
	# we are ready
	@let \scene, scene

	# Run until somebody says "done".
	yield @get \done

export basePedalScene = (env) ->
	env = env with
		controls: NonSteeringControl env.controls
	return baseScene env

catchthething = require './catchthething.ls'
addReactionTest = seqr.bind (scene, env) ->*
	react = yield catchthething.React()
	screen = yield assets.SceneDisplay()

	screen.object.position.z = -0.3
	screen.object.scale.set 0.12, 0.12, 0.12
	screen.object.visible = false
	#screen.object.position.y = 2
	#screen.object.rotation.y = Math.PI
	scene.camera.add screen.object

	env.controls.change (btn, isOn) !->
		if btn == "catch" and isOn and screen.object.visible
			react.catch()
		else if btn == "blinder"
			screen.object.visible = isOn

	react.event (type) ->
		env.logger.write reactionGameEvent: type

	scene.onRender.add (dt) ->
		react.tick dt
		env.renderer.render react.scene, react.camera, screen.renderTarget, true
		#env.renderer.render react.scene, react.camera

	return react


addBlinderTask = (scene, env) ->
	mask = new THREE.Mesh do
		new THREE.PlaneGeometry 0.1*16/9, 0.1
		new THREE.MeshBasicMaterial color: 0x000000
	mask.position.z = -0.3
	mask.position.x = 0.03
	mask.position.y = -0.03
	scene.camera.add mask

	self =
		change: Signal!
		glances: 0

	showMask = ->
		mask.visible = true
		self.change.dispatch true
		env.logger.write blinder: true
	showMask()

	ui.gauge env,
		name: env.L "Glances"
		unit: ""
		value: ->
			self.glances


	env.controls.change (btn, isOn) ->
		return if btn != 'blinder'
		return if isOn != true
		return if not mask.visible
		mask.visible = false
		self.glances += 1
		self.change.dispatch false
		env.logger.write blinder: false
		setTimeout showMask, 300

	return self

addPursuitTask = (scene, env) ->
	mask = new THREE.Mesh do
		new THREE.PlaneGeometry 0.1*16/9, 0.1
		new THREE.MeshBasicMaterial color: 0x000000
	mask.position.z = -0.3
	mask.position.x = 0.03
	mask.position.y = -0.03
	scene.camera.add mask

	self =
		change: Signal!
		glances: 0

	showMask = ->
		mask.visible = true
		self.change.dispatch true
		env.logger.write blinder: true
	showMask()

	#ui.gauge env,
	#	name: env.L "Glances"
	#	unit: ""
	#	value: ->
	#		self.glances


	#env.controls.change (btn, isOn) ->
	#	return if btn != 'blinder'
	#	return if isOn != true
	#	return if not mask.visible
	#	mask.visible = false
	#	self.glances += 1
	#	self.change.dispatch false
	#	env.logger.write blinder: false
	#	setTimeout showMask, 300

	return self



exportScenario \runTheLight, (env) ->*
	@let \intro,
		title: env.L "Run the light"
		subtitle: env.L "(Just this once)"
		content: $ env.L "%runTheLight.intro"

	scene = yield basePedalScene env
	startLight = yield assets.TrafficLight()
	startLight.position.x = -4
	startLight.position.z = 6
	startLight.addTo scene

	@let \scene, scene
	yield @get \run

	scene.player.onCollision (e) ~>
		@let \done, passed: true, outro:
			title: env.L "Passed"
			content: env.L '%runTheLight.outro'

	return yield @get \done

collisionReason = ({L}, e) ->
	switch (e.body.objectClass)
	| 'traffic-light' => L "You ran the red light!"
	| 'stop-sign' => L "You ran the stop sign!"
	| otherwise => L "You crashed!"

failOnCollision = (env, scn, scene) ->
	scene.player.onCollision (e) ->
		reason = collisionReason env, e
		scn.let \done, passed: false, outro:
			title: env.L "Oops!"
			content: reason
		return false

exportScenario \closeTheGap, (env) ->*
	@let \intro,
		title: env.L "Close the gap"
		content: env.L '%closeTheGap.intro'

	scene = yield basePedalScene env
	leader = yield addVehicle scene
	leader.physical.position.x = scene.player.physical.position.x
	leader.physical.position.z = 100

	failOnCollision env, @, scene

	@let \scene, scene

	yield @get \run

	distanceToLeader = ->
		rawDist = scene.player.physical.position.distanceTo leader.physical.position
		return rawDist - scene.player.physical.boundingRadius - leader.physical.boundingRadius

	env.controls.change (btn, isOn) !~>
		return unless btn == 'catch' and isOn
		distance = distanceToLeader!
		distance += 1.47 # HACK!
		@let \done, passed: true, outro:
			title: env.L "Passed"
			content: env.L "%closeTheGap.outro", distance: distance
		return false

	return yield @get \done


exportScenario \throttleAndBrake, (env) ->*
	L = env.L
	@let \intro,
		title: L "Throttle and brake"
		content: L '%throttleAndBrake.intro'

	scene = yield basePedalScene env

	goalDistance = 200
	startLight = yield assets.TrafficLight()
	startLight.position.x = -4
	startLight.position.z = 6
	startLight.addTo scene

	stopSign = yield assets.StopSign!
		..position.x = -4
		..position.z = goalDistance + 10
		..addTo scene

	failOnCollision env, @, scene

	finishSign = yield assets.FinishSign!
	finishSign.position.z = goalDistance
	finishSign.addTo scene
	ui.gauge env,
		name: L "Time"
		unit: L "s"
		value: ->
			if not startTime?
				return 0.toFixed 2
			(scene.time - startTime).toFixed 2


	@let \scene, scene
	yield @get \run

	yield P.delay 2000
	yield startLight.switchToGreen()
	startTime = scene.time

	finishSign.bodyPassed(scene.player.physical).then ~> scene.onTickHandled ~>
		return if Math.abs(scene.player.getSpeed()) > 0.1
		time = scene.time - startTime
		@let \done, passed: true, outro:
			title: L "Passed"
			content: L '%throttleAndBrake.outro', time: time
		return false

	return yield @get \done

speedControl = exportScenario \speedControl, (env) ->*
	L = env.L
	@let \intro,
		title: L "Speed control"
		content: L "%speedControl.intro"

	scene = yield basePedalScene env
	limits = [
		[-Infinity, 50]
		[20, 50]
		[200, 30]
		[250, 80]
		[500, 60]
	]
	goalDistance = 700

	for [dist, limit] in limits
		sign = yield assets.SpeedSign limit
		sign.position.z = dist
		sign.position.x = -4
		scene.visual.add sign
	limits.reverse()
	currentLimit = ->
		mypos = scene.player.physical.position.z
		for [distance, limit] in limits
			break if distance < mypos

		return limit

	limitSign = ui.gauge env,
		name: L "Speed limit"
		unit: L "km/h"
		value: currentLimit

	illGainsMultiplier = 10
	illGains = 0
	timePenalty = 0
	scene.afterPhysics (dt) ->
		return if not startTime?
		limit = currentLimit!
		speed = Math.abs scene.player.getSpeed()*3.6
		if speed <= limit
			limitSign.normal()
			return

		limitSign.warning()
		traveled = (speed/3.6)*dt
		legalMinTime = traveled/(limit/3.6)
		timeGained = legalMinTime - dt

		illGains += timeGained
		timePenalty := illGains*illGainsMultiplier

	ui.gauge env,
		name: L "Penalty"
		unit: "s"
		value: ->
			timePenalty.toFixed 2

	startLight = yield assets.TrafficLight()
	startLight.position.x = -4
	startLight.position.z = 6
	startLight.addTo scene

	stopSign = yield assets.StopSign!
		..position.x = -4
		..position.z = goalDistance + 10
		..addTo scene

	failOnCollision env, @, scene

	scene.player.onCollision (e) ~>
		@let \done, passed: false, outro:
			title: L "Oops!"
			content: L "You ran the red light!"
		return false

	finishSign = yield assets.FinishSign!
	finishSign.position.z = goalDistance
	finishSign.addTo scene

	@let \scene, scene
	yield @get \run

	yield P.delay 1000
	yield startLight.switchToGreen()
	startTime = scene.time

	finishSign.bodyPassed(scene.player.physical).then ~> scene.onTickHandled ~>
		return if Math.abs(scene.player.getSpeed()) > 0.1

		time = scene.time - startTime
		@let \done, passed: true, outro:
			title: L "Passed"
			content: L '%speedControl.outro', time: time, timePenalty: timePenalty
		return false

	return yield @get \done

exportScenario \blindSpeedControl, (env) ->*
	L = env.L
	base = speedControl env

	intro = yield base.get \intro
	@let \intro,
		title: L "Anticipatory speed control"
		content: L '%blindSpeedControl.intro'

	scene = yield base.get \scene

	addBlinderTask scene, env
	@let \scene, scene

	yield @get \run
	base.let \run

	result = yield base.get \done

	@let \done, result

	return result


{IdmVehicle, LoopMicrosim} = require './microsim.ls'

class MicrosimWrapper
	(@phys) ->
	position:~->
		@phys.position.z
	velocity:~->
		@phys.velocity.z

	acceleration:~-> null

	step: ->

{knuthShuffle: shuffleArray} = require 'knuth-shuffle'

{TargetSpeedController} = require './controls.ls'
followInTraffic = exportScenario \followInTraffic, (env) ->*
	L = env.L
	@let \intro,
		title: L "Supermiler"
		content: $ L "%followInTraffic.intro"

	scene = yield basePedalScene env
	#addReactionTest scene, env
	#addBlinderTask scene, env

	startLight = yield assets.TrafficLight()
	startLight.position.x = -4
	startLight.position.z = 6
	startLight.addTo scene

	goalDistance = 2000
	finishSign = yield assets.FinishSign!
	finishSign.position.z = goalDistance
	finishSign.addTo scene

	scene.player.onCollision (e) ~>
		reason = L "You crashed!"
		if e.body.objectClass == "traffic-light"
			reason = L "You ran the red light!"
		@let \done, passed: false, outro:
			title: L "Oops!"
			content: reason
		return false

	maximumFuelFlow = 200/60/1000
	constantConsumption = maximumFuelFlow*0.1
	draftingCoeff = (d) ->
		# Estimated from Mythbusters!
		Math.exp(0) - Math.exp(-(d + 5.6)*0.1)

	consumption =
		time: 0
		distance: 0
		instant: 0
		total: 0
		noDraftTotal: 0
		avgLitersPer100km: (consumption=@total) ->
			metersPerLiter = @distance/consumption
			1.0/metersPerLiter*1000*100
		instLitersPer100km: ->
			metersPerLiter = Math.abs(scene.player.getSpeed())/@instant
			1.0/metersPerLiter*1000*100

	scene.afterPhysics.add (dt) !->
		return if not startTime?
		consumption.time += dt
		consumption.distance += dt*Math.abs(scene.player.getSpeed())
		instant = env.controls.throttle*maximumFuelFlow + constantConsumption
		consumption.instant = instant * draftingCoeff(distanceToLeader!)
		consumption.total += consumption.instant*dt
		consumption.noDraftTotal += instant*dt

	ui.gauge env,
		name: L "Current consumption"
		unit: "l/100km"
		range: [0, 30]
		format: (v) ->
			if Math.abs(scene.player.getSpeed()) < 1.0
				return null
			return v.toFixed 2
		value: ->
			c = consumption.instLitersPer100km!
			return c

	ui.gauge env,
		name: L "Average consumption"
		unit: "l/100km"
		range: [0, 30]
		format: (v) ->
			return null if consumption.distance < 1
			return v.toFixed 2
		value: ->
			return consumption.avgLitersPer100km!

	/*nVehicles = 20
	spacePerVehicle = 20
	traffic = new LoopMicrosim nVehicles*spacePerVehicle
	for i in [1 til nVehicles]
		v = new IdmVehicle do
			a: 4.0
			b: 10.0
			timeHeadway: 1.0
		v.position = i*spacePerVehicle
		traffic.addVehicle v
	scene.beforePhysics.add traffic~step
	scene.traffic = traffic

	playerSim = new MicrosimWrapper scene.player.physical
	traffic.addVehicle playerSim

	leader = yield addVehicle scene
	leader.physical.position.z = playerSim.leader.position
	leader.physical.position.x = -1.75
	scene.beforeRender.add (dt) ->
		leader.forceModelSync()
		leader.physical.position.z = playerSim.leader.position
		leader.forceModelSync()*/

	leaderControls = new TargetSpeedController
	leader = yield addVehicle scene, leaderControls
	leader.physical.position.x = -1.75
	leader.physical.position.z = 10

	speeds = [0, 30, 40, 50, 60, 70, 80]*2
	shuffleArray speeds
	while speeds[*-1] == 0
		shuffleArray speeds
	speedDuration = 10

	sequence = for speed, i in speeds
		[(i+1)*speedDuration, speed/3.6]

	scene.afterPhysics.add (dt) ->
		if scene.time > sequence[0][0] and sequence.length > 1
			sequence := sequence.slice(1)
		leaderControls.target = sequence[0][1]
		leaderControls.tick leader.getSpeed(), dt

	headway =
		cumulative: 0
		time: 0
		average: ->
			@cumulative/@time
	cumHeadway = 0
	averageHeadway = 0
	scene.afterPhysics (dt) ->
		return if not startTime?
		headway.cumulative += dt*distanceToLeader!
		headway.time += dt


	distanceToLeader = ->
		rawDist = scene.player.physical.position.distanceTo leader.physical.position
		return rawDist - scene.player.physical.boundingRadius - leader.physical.boundingRadius

	scene.draftIndicator = ui.gauge env,
		name: L "Draft saving"
		unit: "%"
		#range: [0, 30]
		#format: (v) ->
		#	return null if consumption.distance < 1
		#	return v.toFixed 2
		value: ->
			c = draftingCoeff distanceToLeader!
			((1 - c)*100).toFixed 1

	# Wait for the traffic to queue up
	#while not traffic.isInStandstill()
	#	traffic.step 1/60

	finishSign.bodyPassed(scene.player.physical).then ~>
		@let \done, passed: true, outro:
			title: L "Passed!"
			content: L '%followInTraffic.outro', consumption: consumption
	@let \scene, scene
	yield @get \run
	yield P.delay 1000
	yield startLight.switchToGreen()
	startTime = scene.time

	return yield @get \done


exportScenario \blindFollowInTraffic, (env) ->*
	L = env.L
	base = followInTraffic env

	intro = yield base.get \intro
	@let \intro,
		title: L "Anticipating supermiler"
		content: L '%blindFollowInTraffic.intro'

	scene = yield base.get \scene
	scene.draftIndicator.el.hide()
	addBlinderTask scene, env
	@let \scene, scene

	yield @get \run
	base.let \run

	@get \done .then (result) ->
		base.let \done, result

	result = yield base.get \done

	@let \done, result

	return result

exportScenario \participantInformation, (env) ->*
	L = env.L
	currentYear = (new Date).getFullYear()
	radioSelect = (name, ...options) ->
		for {value, label} in options
			$ """
			<div class="radio">
				<label>
					<input type="radio" name="#name" value="#value">
					#label
				</label>
			</div>
			"""

	dialogs =
		->
			@ \title .text L "Welcome to the experiment"
			@ \text .append L "%intro.introduction"
			@ \accept .text L "Next"
			@ \cancel-button .hide!
		->
			@ \title .text L "Participation is voluntary"
			@ \text .append L "%intro.participantRights"
			@ \cancel .text L "Previous"
			@ \accept .text L "I wish to participate"
		->
			@ \title .text L "Collection and use of data"
			@ \text .append L "%intro.dataUse"
			@ \cancel .text L "Previous"
			@ \accept .text L "I accept the usage of my data"
		->
			@ \title .text L "Background information"
			@ \text .append L "%intro.backgroundInfo"
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
		->
			@ \title .text L "E-mail address"
			@ \text .append L "%intro.email"
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
			input = $('<input name="email" type="email" style="color: black">')
			.prop "placeholder", L "E-mail address"
			.appendTo @ \inputs
			setTimeout input~focus, 0
		->
			@ \title .text L "Birth year"
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
			input = $("""<input name="birthyear" type="number" min="1900" max="#currentYear" style="color: black">""")
			.appendTo @ \inputs
			setTimeout input~focus, 0
		->
			@ \title .text L "Gender"
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
			@ \inputs .append radioSelect "gender",
				* value: 'female', label: L "Female"
				* value: 'male', label: L "Male"
		->
			@ \title .text L "Driving license year"
			@ \text .append L "%intro.license"
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
			input = $("""<input name="drivinglicenseyear" type="number" min="1900" max="#currentYear" style="color: black">""")
			.appendTo @ \inputs
			setTimeout input~focus, 0
		->
			@ \title .text L "Past year driving"
			@ \text .append L "On average, how frequently have you driven during the <strong>past year</strong>."
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
			@ \inputs .append radioSelect "drivingFreqPastYear",
				* value: 'daily', label: L "Most days"
				* value: 'weekly', label: L "Most weeks"
				* value: 'monthly', label: L "Most months"
				* value: 'yearly', label: L "Few times a year"
				* value: 'none', label: L "Not at all"
		->
			@ \title .text L "Lifetime driving"
			@ \text .append L "On average, how frequently have you driven <strong>since you got your driver's license</strong>."
			@ \accept .text L "Next"
			@ \cancel .text L "Previous"
			@ \inputs .append radioSelect "drivingFreqTotal",
				* value: 'daily', label: L "Most days"
				* value: 'weekly', label: L "Most weeks"
				* value: 'monthly', label: L "Most months"
				* value: 'yearly', label: L "Few times a year"
				* value: 'none', label: L "Not at all"

	i = 0
	while i < dialogs.length
		result = yield ui.inputDialog env, dialogs[i]
		console.log result
		if result.canceled
			i -= 2
		i += 1

	#yield ui.inputDialog env, ->
	#	@ \title .text L "Welcome to the experiment"
	#	@ \text .text L "Please type your name."
	#	textbox = $('<input name="name" type="text" style="color: black">')
	#	.appendTo @ \content
	#	setTimeout textbox~focus, 0

/*
exportScenario \blindPursuit, (env) ->*
	react = new catchthething.Catchthething()
	screen = yield assets.SceneDisplay()

	screen.object.position.z = -0.3
	screen.object.scale.set 0.12, 0.12, 0.12
	screen.object.visible = false
	#screen.object.position.y = 2
	#screen.object.rotation.y = Math.PI
	scene.camera.add screen.object

	env.controls.change (btn, isOn) !->
		if btn == "catch" and isOn and screen.object.visible
			react.catch()
		else if btn == "blinder"
			screen.object.visible = isOn

	react.event (type) ->
		env.logger.write reactionGameEvent: type

	scene.onRender.add (dt) ->
		react.tick dt
		env.renderer.render react.scene, react.camera, screen.renderTarget, true
		#env.renderer.render react.scene, react.camera

	return react
*/

exportScenario \blindPursuit, (env) ->*
	L = env.L
	#base = module.exports.freeDriving env

	#intro = yield base.get \intro
	#@let \intro,
	#	title: L "Anticipating supermiler"
	#	content: L '%blindFollowInTraffic.intro'

	scene = new Scene

	scene.preroll = ->
		# Tick a couple of frames for the physics to settle
		scene.tick 1/60
		n = 100
		t = Date.now()
		for [0 to n]
			scene.tick 1/60
		console.log "Prewarming FPS", (n/(Date.now() - t)*1000)


	screen = yield assets.SceneDisplay()

	screen.object.position.z = -0.1
	screen.object.scale.set 0.1, 0.1, 0.1
	screen.object.visible = true
	#screen.object.position.y = 2
	#screen.object.rotation.y = Math.PI
	scene.visual.add screen.object

	catcher = new catchthething.Catchthething()

	env.controls.change (btn, isOn) !->
		if btn == "catch" and isOn and screen.object.visible
			catcher.catch()


	scene.onRender.add (dt) ->
		catcher.tick dt
		env.renderer.render catcher.scene, catcher.camera, screen.renderTarget, true

	@let \scene, scene

	yield @get \run

	#@get \done .then (result) ->
	#	base.let \done, result

	#result = yield base.get \done

	yield @get \done

	#@let \done, result

	return result

