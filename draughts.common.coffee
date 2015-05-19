Db = require 'db'

exports.init = !->
    mode = Db.shared.peek 'mode'
    Db.shared.set 'board', do ->
        board = {}
        if mode isnt 1
            for i in [0...20]
                board[i] = 'ws'
            for i in [30...50]
                board[i] = 'bs'
        else if mode is 1
            for i in [0...10]
                board[i] = 'wk'
            for i in [40...50]
                board[i] = 'bk'
        board
    Db.shared.set 'turn', 'white'
    Db.shared.set 'moveId', 1

exports.index = index = (x, y) ->
    return y * 5 + x // 2

fromIndex = (p) ->
    y = p//5
    x = (p % 5) * 2 + y % 2
    return [x, y]

exports.move = (from, to) ->
    board_ref = Db.shared.ref 'board'
    last_ref = Db.shared.peek 'captured'
    last_dx = if last_ref then Db.shared.peek 'dx' else null
    last_dy = if last_ref then Db.shared.peek 'dy' else null

    return false if not board_ref or not canMove(from, to)

    board = board_ref.get()

    [c,p] = board[from]

    caps = listMaxCaptures(board,from,last_dx,last_dy)
    capture = 0 < caps[0]
    more = 1 < caps[0]
    if not more
        for pos of board
            if board[pos]?[0] is 'g'
                board_ref.remove pos

    [x1,y1] = fromIndex from
    [x2,y2] = fromIndex to

    dx = if 0 < x1 - x2 then -1 else 1
    dy = if 0 < y1 - y2 then -1 else 1

    if not more and ((c is 'w' and y2 is 9) or (c is 'b' and y2 is 0))
        board_ref.set to, c + 'k'
    else
        board_ref.set to, c + p

    xs = [x1..x2][1...-1]
    ys = [y1..y2][1...-1]

    for i in [0...(xs.length)]
        pos = index xs[i], ys[i]
        if board[pos]
            if more
                board_ref.set pos, 'g' + board[pos][1]
            else
                board_ref.remove pos

    board_ref.remove from

    Db.shared.set 'last', {0:from, 1:to}

    if not capture or not more
        color = Db.shared.modify 'turn', (t) -> if t is 'white' then 'black' else 'white'
#        log 'lost: '+ hasLost(board_ref.get(),otherColor(c))
        if hasLost(board_ref.get(), color[0])
            Db.shared.set 'result', if color is 'white' then 'black' else 'white'
        else if color is 'white'
            Db.shared.modify 'moveId', (m) -> m + 1
        Db.shared.remove 'captured'
        Db.shared.remove 'dx'
        Db.shared.remove 'dy'
    else
        log "move again"
        Db.shared.set 'captured', to
        Db.shared.set 'dx', dx
        Db.shared.set 'dy', dy

    (from+1) + (if capture then 'x' else '-') + (to+1)

exports.canMove = canMove = (from, to) ->
    square = Db.shared.get('board', from)
    return false if not square

    [color,piece] = square

    return false if color isnt Db.shared.get('turn')[0]

    to in find(from)

hasLost = (board, forColor) ->
    [max,_] = listMaxCapturesBoard(board, forColor)
    return false if max isnt 0
    for pos in [0...50]
        if board[pos]?[0] is forColor
            return false if findMoves(board, pos, 0, [],null,null).length isnt 0
    return true

exports.find = find = (base) ->
    board = Db.shared.peek('board')
    last = Db.shared.peek 'captured'
    last_dx = if last then Db.shared.peek 'dx' else null
    last_dy = if last then Db.shared.peek 'dy' else null
    [color,piece] = board[base]
    max = 0
    captures = []
    last_dx = null
    last_dy = null
    if last and last_dx and last_dy
        if last is base
            return (listMaxCaptures board,base,last_dx,last_dy)[1]
        else
            return []
    else
        [max,captures] = listMaxCapturesBoard(board, color)
        log "max: " + max
        return findMoves board, base, max, captures, last_dx, last_dy

findMoves = (board, pos, max, captures, base_dx, base_dy) ->
    # get array of possible moves from a given start location

    if max is 0
        [color,piece] = board[pos]
        [x,y] = fromIndex(pos)
        moves = []
        if piece is 's'
            dy = if color is 'w' then 1 else -1
            for dx in [-1, 1]
                if 0 <= x + dx < 10 and 0 <= y + dy < 10
                    np = index(x + dx, y + dy)
                    if not board[np]
                        # log 'move: '+np
                        moves.push(np)
        else
            for [dx, dy] in [[-1, -1],[1, -1],[-1, 1],[1, 1]]
                i = 1
                p2 = index(x + i * dx, y + i * dy)
                while 0 <= x + i * dx < 10 and 0 <= y + i * dy < 10 and not board[p2]
                    moves.push(p2)
                    i++
                    p2 = index(x + i * dx, y + i * dy)
        return moves
    else
        captures = listMaxCaptures(board,pos,base_dx,base_dy)
        if captures[0] is max
            return captures[1]
        else
            return []

listMaxCapturesBoard = (board, color) ->
    result = [0,[]]
    for pos in [0...50]
        if board[pos]?[0] is color
            captures = (listMaxCaptures board,pos,null,null)[0]
            if result[0] < captures
                result = [captures, [pos]]
            else if result[0] is captures and result[0] isnt 0
                result[1].push pos
    result

# returns [max,[move_to, ... ]]
listMaxCaptures = (board,base,base_dx,base_dy) ->
    max = [0,[]]
    captures = listCaptures board,base,base_dx,base_dy
    for cap in captures
        [board_new,moves_to,dx,dy] = cap
        [max_new,_] = listMaxCaptures board_new,moves_to,dx,dy
        max_new++
        if max[0] < max_new
            max = [max_new,[moves_to]]
        else if max[0] is max_new
            max[1].push moves_to
    max

# returns [[board,moves_to,dx,dy], ... ]
listCaptures = (board,base,base_dx,base_dy) ->
    directions = []
    if base_dx and base_dy
        directions = [[base_dx*-1,base_dy],[base_dx,base_dy*-1],[base_dx,base_dy]]
    else
        directions = [[1,1],[-1,1],[1,-1],[-1,-1]]
    [color,piece] = board[base]
    not_color = otherColor color
    moves = []
    [x,y] = fromIndex base
    if piece is 's'
        for [dx, dy] in directions
            p1 = index x + dx       , y + dy
            p2 = index x + dx * 2   , y + dy * 2
            if 0 <= x + 2 * dx < 10 and 0 <= y + 2 * dy < 10 and board[p1]?[0] is not_color and not board[p2]
                moves.push [takeStone(board,base,p1,p2),p2,dx,dy]
    else
        for [dx, dy] in directions
            i = 1
            while 0 <= x + i * dx < 10 and 0 <= y + i * dy < 10 and not board[index(x + i * dx, y + i * dy)]
                i++
            p1 = index x + i * dx, y + i * dy
            if 0 <= x + i * dx < 10 and 0 <= y + i * dy < 10 and board[p1][0] is not_color
                i++
                p2 = index x + i * dx, y + i * dy
                while 0 <= x + i * dx < 10 and 0 <= y + i * dy < 10 and not board[p2]
                    moves.push [takeStone(board,base,p1,p2),p2,dx,dy]
                    i++
                    p2 = index x + i * dx, y + i * dy
    moves


takeStone = (board, pos, p1, p2) ->
    result = clone board
    result[p2] = '' + result[pos]
    [color,piece] = result[p1]
    delete result[pos]
    result[p1] = 'g'+piece
    return result

otherColor = (color) ->
    if color is 'w'
        'b'
    else
        'w'

exports.otherPlayer = (player) ->
	log 'Getting other player from ', player
	if Db.shared.get('black') is player
		log 'Was ', Db.shared.get 'white'
		return Db.shared.get 'white'
	else
		log 'Was ', Db.shared.get 'black'
		return Db.shared.get 'black'

clone = (obj) ->
    newInstance = {}
    # logmessage = "dict:\n"
    for key of obj
        if obj[key]
            # logmessage += "key: "+key+" val: "+obj[key]+"\n"
            newInstance[key] = '' + obj[key]
    # log logmessage
    newInstance
