Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
Social = require 'social'
Draughts = require 'draughts'
{tr} = require 'i18n'

modes = ['International Draughts','Siamese Draughts']

exports.renderSettings = !->
	Dom.div !->
		Dom.style margin: '16px -8px'

		if Db.shared
			Ui.emptyText tr("Game has started")
		else
			Form.sep()
			userCnt = Plugin.users.count().get()
			selUserId = null
			if userCnt is 2
				for userId, v of Plugin.users.get()
					if +userId isnt Plugin.userId()
						selUserId = userId
						break

			selectMember
				name: 'opponent'
				value: selUserId
				title: tr("Opponent")
			Form.sep()
			Form.condition (val) ->
				tr("Please select an opponent") if !val.opponent

			selectMode
				name: 'mode'
				title: tr('Mode')
			Form.sep()

exports.render = !->
	whiteId = Db.shared.get('white')
	blackId = Db.shared.get('black')
	color = if Plugin.userId() is whiteId
		'white'
	else if Plugin.userId() is blackId
		'black'

	if challenge = Db.shared.get('challenge')
		Dom.div !->
			Dom.style
				padding: '8px'
				textAlign: 'center'
				fontSize: '120%'

			Dom.text tr("%1 (white) vs %2 (black)", Plugin.userName(whiteId), Plugin.userName(blackId))

			if challenge[Plugin.userId()]
				Dom.div tr("%1 challenged you for a game of %2.", Plugin.userName(Plugin.ownerId()), modes[Db.shared.get 'mode'])

				Ui.bigButton tr("Accept"), !->
					Server.call 'accept'
			else
				break for id of challenge
				Dom.div tr("Waiting for %1 to accept...", Plugin.userName(id))

	else
		isBlack = Db.shared.get('black') is Plugin.userId() and Db.shared.get('white') isnt Plugin.userId()

		renderSide = (side) !->
			Dom.div !->
				Dom.style
					textAlign: 'center'
					fontSize: '130%'
					padding: '8px 0'
					color: 'inherit'
					fontWeight: 'normal'
				id = Db.shared.get(side)
				if id is Plugin.userId()
					Dom.text tr("You")
				else
					Dom.text Plugin.userName(id)

				if result = Db.shared.get('result')
					Dom.style fontWeight: 'bold'
					if result is side
						if id is Plugin.userId()
							Dom.text " - win!"
						else
							Dom.text " - wins!"
					else if result is 'draw'
						Dom.text " - draw"
					else if result
						Dom.text " - lost"

				else if Db.shared.get('turn') is side
					if id is Plugin.userId()
						Dom.style color: Plugin.colors().highlight, fontWeight: 'bold'
					Dom.text " - to move"

		renderSide if isBlack then 'white' else 'black'

		Dom.div !->
			Dom.style
				Box: 'center'
				margin: '4px 0'

			selected = Obs.create false
			markers = Obs.create {}
			# Draughts field index indicating last-moved-piece, selected, possible-move

			Obs.observe !->
				if last = Db.shared.get('last')
					markers.set last[0], 'last'
					markers.set last[1], 'last'

				if s = selected.get()
					s-=1
					markers.set s, 'selected'
					for pos in Draughts.find(s)
						log 'pos: '+pos
						markers.set pos, 'move'
#        require('toast').show tr(""+s)

				Obs.onClean !->
					markers.set {}

			Dom.div !->
				size = 0 | Math.max(200, Math.min(Dom.viewport.get('width') - 16, 480)) / 10
				Dom.cls 'board'
				Dom.style width: "#{size * 10}px"

				(if isBlack then [0..9] else [9..0]).forEach (board_y) !->
					Dom.div !->
						(if isBlack then [9..0] else [0..9]).forEach (board_x) !->
							Dom.div !->
								cb = (board_x % 2) is (board_y % 2)
								Dom.cls 'square'

								if cb
									Dom.cls 'black'
									index = Draughts.index(board_x, board_y)
									piece = Db.shared.get('board',index)
#                  Dom.text index
									if marker = markers.get(index)
										Dom.div !->
											Dom.style
												position: 'absolute'
												width: if piece then '90%' else '50%'
												height: if piece then '90%' else '50%'
												left: if piece then '5%' else '25%'
												top: if piece then '5%' else '25%'
												background: if marker is 'last' then Plugin.colors().bar else Plugin.colors().highlight
												opacity: if marker is 'last' then .6 else 0.9
												borderRadius: '999px'

									if piece
										Dom.div !->
											Dom.style
												position: 'absolute'
												left: 0
												top: 0
												width: '100%'
												height: '100%'
												background: "url(#{Plugin.resourceUri piece + '.png'}) no-repeat 50% 50%"
												backgroundSize: "#{0 | size * .75}px"

									if not Db.shared.get('result')
										Dom.onTap !->
											turn = Db.shared.get('turn')
											if turn is color
												s = selected.get()
												if !s and piece and piece[0] is turn[0]
													selected.set index+1
													return

												if s and s-1 isnt index and Db.shared.peek('board',index)?[0] isnt turn[0]
													s-=1
													log 'move', s, '>', index
													if markers.get(index) is 'move' and Draughts.canMove(s, index)
#                            log 'server call'
														Server.call 'move', s, index
#                            log 'done server call'
													else
														require('toast').show tr("Invalid move!")

											selected.set false

		renderSide if isBlack then 'black' else 'white'

		if (Plugin.userId() is blackId or Plugin.userId() is whiteId) and not Db.shared.get('result')
			Dom.div !->
				Dom.style textAlign: 'center'
				if not (draw = Db.shared.get 'draw')
					Ui.button tr("Propose Draw"), !->
						Modal.show tr("Are you sure you want to propose a draw?"), null, (choice) !->
							if choice is 'yes'
								log "draw"
								Server.call 'draw'
						, ['no',tr('No'),'yes',tr('Yes')]
				else if Db.shared.get(draw) is Plugin.userId()
					Ui.button tr("Decline Draw"), !->
						Modal.show tr("Are you sure you want to decline the draw?"), null, (choice) !->
							if choice is 'yes'
								log "draw decline"
								Server.call 'draw_decline'
						, ['no',tr('No'),'yes',tr('Yes')]
					Ui.button tr("Accept Draw"), !->
						Modal.show tr("Are you sure you want to accept the draw?"), null, (choice) !->
							if choice is 'yes'
								log "draw accept"
								Server.call 'draw_accept'
						, ['no',tr('No'),'yes',tr('Yes')]
				else
					Dom.div !->
						Dom.text('Waiting for a response to your draw request.')

				Ui.button tr("Resign"), !->
					Modal.show tr("Are you sure you want to resign?"), null, (choice) !->
						if choice is 'yes'
							log "resign"
							Server.call 'resign'
					, ['no',tr('No'),'yes',tr('Yes')]

	Social.renderComments()

# input that handles selection of a member
selectMember = (opts) !->
	opts ||= {}
	[handleChange, initValue] = Form.makeInput opts, (v) ->
		0 | v

	value = Obs.create(initValue)
	Form.box !->
		Dom.style fontSize: '125%', paddingRight: '56px'
		Dom.text opts.title || tr("Selected member")
		v = value.get()
		Dom.div !->
			Dom.style color: (if v then 'inherit' else '#aaa')
			Dom.text (if v then Plugin.userName(v) else tr("Nobody"))
		if v
			Ui.avatar Plugin.userAvatar(v), style: position: 'absolute', right: '6px', top: '50%', marginTop: '-20px'

		Dom.onTap !->
			Modal.show opts.selectTitle || tr("Select member"), !->
				Dom.style width: '80%'
				Dom.div !->
					Dom.style
						maxHeight: '40%'
						backgroundColor: '#eee'
						margin: '-12px'
					Dom.overflow()

					Plugin.users.iterate (user) !->
						if Plugin.userId() isnt user
							Ui.item !->
								Ui.avatar user.get('avatar')
								Dom.text user.get('name')

								if +user.key() is +value.get()
									Dom.style fontWeight: 'bold'

									Dom.div !->
										Dom.style
											Flex: 1
											padding: '0 10px'
											textAlign: 'right'
											fontSize: '150%'
											color: Plugin.colors().highlight
										Dom.text "✓"

								Dom.onTap !->
									handleChange user.key()
									value.set user.key()
									Modal.remove()
			, (choice) !->
				log 'choice', choice
				if choice is 'clear'
					handleChange ''
					value.set ''
			, ['cancel', tr("Cancel"), 'clear', tr("Clear")]

############### MODE
selectMode = (opts) !->
	opts ||= {}

	[handleChange, initValue] = Form.makeInput opts, (v) ->
		0 | v

	value = Obs.create(initValue)
	Form.box !->
		Dom.style fontSize: '125%', paddingRight: '56px'
		Dom.text opts.title || tr("Select Mode")
		v = value.get()
		Dom.div !->
			Dom.style color: 'inherit'
			Dom.text modes[v]

		Dom.onTap !->
			Modal.show opts.selectTitle || tr("Select mode"), !->
				Dom.style width: '80%'
				Dom.div !->
					Dom.style
						maxHeight: '40%'
						backgroundColor: '#eee'
						margin: '-12px'
					Dom.overflow()

					modes.forEach (txt,key) !->
						Ui.item !->
							Dom.text txt

							if key is value.get()
								Dom.style fontWeight: 'bold'

								Dom.div !->
									Dom.style
										Flex: 1
										padding: '0 10px'
										textAlign: 'right'
										fontSize: '150%'
										color: Plugin.colors().highlight
									Dom.text "✓"

							Dom.onTap !->
								handleChange key
								value.set key
								Modal.remove()
			, (choice) !->
				log 'choice', choice
				if choice is 'clear'
					handleChange ''
					value.set ''
			, ['cancel', tr("Cancel")]

Dom.css
	'.board':
		boxShadow: '0 0 8px #000'
	'.square':
		display: 'inline-block'
		width: '10%'
		padding: '10% 0 0' # use padding-top trick to maintain aspect ratio
		position: 'relative'
	'.square.white':
		backgroundColor: 'rgb(244,234,193)'
	'.square.black':
		backgroundColor: 'rgb(223,180,135)'
