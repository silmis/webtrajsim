$ = require 'jquery'
P = require 'bluebird'
seqr = require './seqr.ls'
{runScenario, newEnv} = require './scenarioRunner.ls'
scenario = require './scenario.ls'
{flatten, zip, elem-indices, concat, minimum} = require 'prelude-ls'

L = (s) -> s

runUntilPassed = seqr.bind (scenarioLoader, {passes=2, maxRetries=5, params={}}={}) ->*
	currentPasses = 0
	for retry from 1 til Infinity
		task = runScenario scenarioLoader, params
		result = yield task.get \done
		currentPasses += result.passed

		doQuit = currentPasses >= passes or retry > maxRetries
		#if not doQuit
		#	result.outro \content .append $ L "<p>Let's try that again.</p>"
		yield task
		if doQuit
			break

shuffleArray = (a) ->
	i = a.length
	while (--i) > 0
		j = Math.floor (Math.random()*(i+1))
		[a[i], a[j]] = [a[j], a[i]]
	return a


export mulsimco2015 = seqr.bind ->*
	env = newEnv!
	yield scenario.participantInformation yield env.get \env
	env.let \destroy
	yield env

	#yield runScenario scenario.runTheLight
	yield runUntilPassed scenario.closeTheGap, passes: 3

	yield runUntilPassed scenario.throttleAndBrake
	yield runUntilPassed scenario.speedControl
	yield runUntilPassed scenario.blindSpeedControl

	yield runUntilPassed scenario.followInTraffic
	yield runUntilPassed scenario.blindFollowInTraffic

	ntrials = 4
	scenarios = []
		.concat([scenario.followInTraffic]*ntrials)
		.concat([scenario.blindFollowInTraffic]*ntrials)
	scenarios = shuffleArray scenarios

	for scn in scenarios
		yield runScenario scn

	intervals = shuffleArray [1, 1, 2, 2, 3, 3]
	for interval in intervals
		yield runScenario scenario.forcedBlindFollowInTraffic, interval: interval

	env = newEnv!
	yield scenario.experimentOutro yield env.get \env
	env.let \destroy
	yield env

{permuteList} = require './utils.ls'
export easyrider2016 = seqr.bind ->*
	env = newEnv!
	yield scenario.participantInformation yield env.get \env
	logger = (yield env.get(\env)).logger
	env.let \destroy
	yield env
	
	# training
	yield runUntilPassed scenario.closeTheGap, passes: 3
	yield runUntilPassed scenario.throttleAndBrake, passes: 2
	yield runUntilPassed scenario.speedControl, passes: 1
	yield runUntilPassed scenario.inTraffic, passes: 1

	# experiment
	blocksize = 4
	speeds = [10, 30, 50, 80]
	accel_params = [[1.0, 0.1], [0.6, 0.075], [0.4, 0.05]]	

	# speeds
	permutations = permuteList speeds
	permutations = shuffleArray permutations
	[p.push(0) for p in permutations]
	
	# accelerations, this is terrible
	assigned = {}
	acp_list = []

	flat = flatten(permutations)
	[a, b] = [(flat.slice i) for i from 0 to 1]
	pairs = zip a, b
	for p in pairs
		assigned[p] = []

	for p in pairs
		loop
			select = Math.floor (Math.random! * accel_params.length)
			count = elem-indices accel_params[select], assigned[p]
			count = count.length
			if count >= 2
				continue
			else
				acp_list.push accel_params[select]
				assigned[p].push accel_params[select]
				break

	# find the one unassigned value (really terrible, sorry)
	counts = [[x, (elem-indices x, acp_list).length] for x in accel_params]
	minval = 99
	minparam = 0
	for i in counts
		if i[1] < minval
			minval = i[1]
			minparam = i[0]
	acp_list.splice 0, 0, minparam
			
	#console.log counts
	#console.log minparam

	seq = [i * (speeds.length+1) for i from 0 to permutations.length]
	acp_sliced = [acp_list.slice i, i+(speeds.length+1) for i in seq]
	acp_sliced = acp_sliced.slice  0, -1

	# chop up to blocks
	block_i = [x*blocksize for x from 0 to permutations.length/blocksize]	
	block_speeds = []
	block_accels = []
	for i from 0 to block_i.length-2
		bs = permutations.slice block_i[i], block_i[i+1]
		ba = acp_sliced.slice block_i[i], block_i[i+1]
		block_speeds.push flatten bs
		block_accels.push concat ba

	experimentInfo =
		easyRiderRandomSequence: permutations
		easyRiderAccelParameters: acp_sliced	
	logger.write experimentInfo

	for i from 0 to block_speeds.length-1
		blk_s = block_speeds[i]
		blk_a = block_accels[i]
		yield runUntilPassed scenario.easyRider,
			passes: 1,
			maxRetries: 2,
			params: 
				sequence: blk_s
				acceleration: blk_a
				currentSegment: i
				segmentNro: block_speeds.length

	env = newEnv!
	yield scenario.experimentOutro yield env.get \env
	env.let \destroy
	yield env

export defaultExperiment = easyrider2016

export freeDriving = seqr.bind ->*
	yield runScenario scenario.freeDriving

runWithNewEnv = seqr.bind (scenario, ...args) ->*
	envP = newEnv!
	env = yield envP.get \env
	ret = yield scenario env, ...args
	envP.let \destroy
	yield envP
	return ret

export blindPursuit = seqr.bind ->*
	yield runWithNewEnv scenario.participantInformationBlindPursuit
	totalScore =
		correct: 0
		incorrect: 0
	yield runWithNewEnv scenario.soundSpook, preIntro: true

	runPursuitScenario = seqr.bind (...args) ->*
		task = runScenario ...args
		env = yield task.get \env
		res = yield task.get \done

		totalScore.correct += res.result.score.correct
		totalScore.incorrect += res.result.score.incorrect
		totalPercentage = totalScore.correct/(totalScore.correct + totalScore.incorrect)*100
		res.outro \content .append $ env.L "%blindPursuit.totalScore", score: totalPercentage
		yield task
		return res
	res = yield runPursuitScenario scenario.pursuitDiscriminationPractice
	frequency = res.result.estimatedFrequency
	nBlocks = 2
	trialsPerBlock = 2
	for block from 0 til nBlocks
		for trial from 0 til trialsPerBlock
			yield runPursuitScenario scenario.pursuitDiscrimination, frequency: frequency
		yield runWithNewEnv scenario.soundSpook

	env = newEnv!
	yield scenario.experimentOutro (yield env.get \env), (env) ->
		totalPercentage = totalScore.correct/(totalScore.correct + totalScore.incorrect)*100
		@ \content .append env.L '%blindPursuit.finalScore', score: totalPercentage
	env.let \destroy
	yield env

deparam = require 'jquery-deparam'
export singleScenario = seqr.bind ->*
	# TODO: The control flow is a mess!
	opts = deparam window.location.search.substring 1
	scn = scenario[opts.singleScenario]
	while true
		yield runScenario scn



export memkiller = seqr.bind !->*
	#loader = scenario.minimalScenario
	loader = scenario.blindFollowInTraffic
	#for i from 1 to 1
	#	console.log i
	#	scn = loader()
	#	yield scn.get \scene
	#	scn.let \run
	#	scn.let \done
	#	yield scn
	#	void

	for i from 1 to 10
		console.log i
		yield do seqr.bind !->*
			runner = runScenario loader
			[scn] = yield runner.get 'ready'
			console.log "Got scenario"
			[intro] = yield runner.get 'intro'
			if intro.let
				intro.let \accept
			yield P.delay 1000
			scn.let 'done', passed: false, outro: title: "Yay"
			runner.let 'done'
			[outro] = yield runner.get 'outro'
			outro.let \accept
			console.log "Running"
			yield runner
			console.log "Done"

		console.log "Memory usage: ", window.performance.memory.totalJSHeapSize/1024/1024
		if window.gc
			for i from 0 til 10
				window.gc()
			console.log "Memory usage (after gc): ", window.performance.memory.totalJSHeapSize/1024/1024
	return i

export logkiller = seqr.bind !->*
	scope = newEnv!
	env = yield scope.get \env
	for i from 0 to 1000
		env.logger.write foo: "bar"

	scope.let \destroy
	yield scope
	console.log "Done"

