Comments = require 'comments'
Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
Draughts = require 'draughts'

exports.onInstall = (config) !->
	log "onInstall -", JSON.stringify(config)
	if config and not config.mode
		config.mode = 0
	log "onInstall1-", JSON.stringify(config)
	if config and config.opponent
		config = if Math.random()>.5
			{white: Plugin.userId(), black: config.opponent, mode: config.mode}
		else
			{black: Plugin.userId(), white: config.opponent, mode: config.mode}
	if config and config.white and config.black
		challenge = {}
		challenge[+config.white] = true
		challenge[+config.black] = true
		Db.shared.set
			white: +config.white
			black: +config.black
			mode: +config.mode
			challenge: challenge

		Event.create
			unit: 'game'
			text: "#{Plugin.userName()} wants to play"
			#text_you: "you challenged #{xx}"
			for: x=[+config.white, +config.black]
			# new: [-Plugin.userId()]

		accept(Plugin.userId())
			# todo: this currently shows some error due to a framework Db issue

exports.onUpgrade = !->
	log 'Upgraded'
	if !Db.shared.get('board') and game=Db.shared.get('game')
		# version 2.0 clients had their data in /game
		log 'upgrading'
		Db.shared.merge game
		# we'll let the old data linger

exports.onConfig = !->
	# currently, no config can be changed

exports.getTitle = ->
	Plugin.userName(Db.shared.get('white')) + ' vs ' + Plugin.userName(Db.shared.get('black'))

exports.client_accept = !->
	accept(Plugin.userId())

accept = (userId) !->
	log 'accept', userId
	Db.shared.remove 'challenge', userId
	if !Object.keys(Db.shared.get('challenge')).length # objEmpty(...)
		log 'game begin'
		Db.shared.remove 'challenge'
		Event.create
			unit: 'game'
			text: "Draughts game has begun!"
			for: [Draughts.otherPlayer(Plugin.userId())]
		Draughts.init()

exports.client_move = (from, to) !->
	log 'request to move: ' + from + ' to: ' + to
	Db.shared.remove 'draw'
	game = Db.shared.ref('game')
	if Db.shared.get(Db.shared.get('turn')) is Plugin.userId()
		m = Draughts.move from, to
		log m

		Comments.post
			s: 'move'
			v: ''+m
			path: '/'
			pushText: "#{Plugin.userName()} moved #{m}"
			for: [Draughts.otherPlayer(Plugin.userId())]

exports.client_resign = () !->
	log 'resign'
	if Db.shared.get('white') is Plugin.userId()
		Db.shared.set 'result', 'black'
	else if Db.shared.get('black') is Plugin.userId()
		Db.shared.set 'result', 'white'
	else
		return

	Comments.post
		s: 'resign'
		path: '/'
		pushText: "#{Plugin.userName()} has resigned"
		for: [Draughts.otherPlayer(Plugin.userId())]

exports.client_draw = () !->
	log 'draw propose'
	if Db.shared.get('white') is Plugin.userId()
		Db.shared.set 'draw', 'black'
	else if Db.shared.get('black') is Plugin.userId()
		Db.shared.set 'draw', 'white'
	else
		return

	Comments.post
		s: 'proposeDraw'
		path: '/'
		pushText: "#{Plugin.userName()} has proposed a draw"
		for: [Draughts.otherPlayer(Plugin.userId())]

exports.client_draw_accept = () !->
	log 'draw accepted'
	if draw = Db.shared.get 'draw'
		if Db.shared.get(draw) is Plugin.userId()
			Db.shared.remove 'draw'
			Db.shared.set 'result', 'draw'

			Comments.post
				s: 'acceptDraw'
				path: '/'
				pushText: "#{Plugin.userName()} has accepted the draw"
				for: [Draughts.otherPlayer(Plugin.userId())]

exports.client_draw_decline = () !->
	log 'draw declined'
	if proposer = Db.shared.get 'draw'
		if Db.shared.get(proposer) is Plugin.userId()
			Db.shared.remove 'draw'

			Comments.post
				s: 'declineDraw'
				path: '/'
				pushText: "#{Plugin.userName()} has declined the draw"
				for: [Draughts.otherPlayer(Plugin.userId())]