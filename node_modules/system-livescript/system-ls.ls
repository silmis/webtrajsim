livescript = require 'livescript'

export translate = (load) ->
	resultAddress = load.address + ".js"
	result = livescript.compile load.source,
		filename: load.address
		outputFilename: resultAddress
		map: "linked"
		bare: true
		const: false
		header: false

	result.map.setSourceContent load.address, load.source
	load.source = result.code
	load.metadata.sourceMap = result.map

