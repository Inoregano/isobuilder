love.graphics.setDefaultFilter("nearest")
math.randomseed(os.time())

local gl = {
	cellSize = 16,
	windowWidth = 256,
	windowHeight = 160,
	windowScale = 2,
	camera = {
		x = 0,
		y = 0
	}
}
gl.gridStartingX = gl.windowWidth / 2
gl.gridStartingY = (gl.windowHeight / 2) - 64


function gl.clamp(val, min, max) if val < min then return min elseif val > max then return max end return val end

function gl.getScrCoords(x, y, both)
	if both == true then return (x * 1 + y * -1), (x * 0.5 + y * 0.5) end
	return {x=(x * 1 + y * -1), y=(x * 0.5 + y * 0.5)}
end
function gl.getIsoCoords(x, y, both)
	local rx = math.floor(
		(
			((x - gl.gridStartingX) / gl.cellSize - gl.camera.x * 2) + 
			((y - gl.gridStartingY) / (gl.cellSize / 2) - gl.camera.y * 2)
		) / 2
	) + 1
	local ry = math.floor(
		(
			((y - gl.gridStartingY) / (gl.cellSize / 2) - gl.camera.y * 2) - 
			((x - gl.gridStartingX) / gl.cellSize - gl.camera.x * 2)
		) / 2
	) + 1

	if both == true then return rx, ry end
	return {x=rx, y=ry}
end

love.window.setMode(gl.windowWidth * gl.windowScale, gl.windowHeight * gl.windowScale)

function newSheet(img, cellX, cellY)
	cellY = cellY or cellX
	local sheet = {
		img = love.graphics.newImage(img),
		quads = {},
	}
	sheet.width = sheet.img:getWidth() / cellX
	sheet.height = sheet.img:getHeight() / cellY
	sheet.batch = love.graphics.newSpriteBatch(sheet.img)
	for y = 1, sheet.height do
		sheet.quads[y] = {}
		for x = 1, sheet.width do
			sheet.quads[y][x] = love.graphics.newQuad(
				(x - 1) * cellX,
				(y - 1) * cellY,
				cellX, cellY,
				sheet.img
			)
		end
	end

	return sheet
end

local a = {
	tiles = newSheet("assets/tiles-iso.png", gl.cellSize * 2, gl.cellSize),
	cursor = love.graphics.newImage("assets/cursor.png"),
}

function newEntity(name)
	local entity = {
		occupies = {1, 1},
		check = "hello and welcome to the test entity.\ni hope you have a great day"
	}
	entity.name = name
	return entity
end
function newRoom(width, height)
	local room = {
		width = width,
		height = height,
		tiles = {},
		entities = {},
	}
	for y = 1, room.height do
		room.tiles[y] = {}
		for x = 1, room.width do
			room.tiles[y][x] = {
				value = 2,
				type = 1,
				canWalk = true,
				entity = {
					key = "",
					isPointer = false,
					pointer = {},
				},
			}
		end
	end
	
	function room:addEntity(name, x, y)
		local key 
		--this is surely the cleanest way of generating a random string
		while true do
			key =
				string.char(math.random(65, 65 + 25)):lower()..
				string.char(math.random(65, 65 + 25)):lower()..
				string.char(math.random(65, 65 + 25)):lower()..
				string.char(math.random(65, 65 + 25)):lower()..
				string.char(math.random(65, 65 + 25)):lower()..
				string.char(math.random(65, 65 + 25)):lower()
			if self.entities[key] == nil then
				break
			end
		end
		
		self.entities[key] = newEntity(name)
		self.entities[key].x, self.entities[key].y = x, y

		self.tiles[y][x].entity.key = key
		for ty = 1, self.entities[key].occupies[2] do
			for tx = 1, self.entities[key].occupies[1] do
				if not (ty == 1 and tx == 1) then
					self.tiles[ty][tx].entity.isPointer = true
					self.tiles[ty][tx].entity.pointer = {x, y}
				end
			end
		end
	end
	
	function room:getEntity(x, y, type, reps)
		reps = reps or 0
		if not self.tiles[y] or not self.tiles[y][x] then return nil end
		if self.tiles[y][x].entity.isPointer then
			if reps > 0 then 
				print(self.tiles[y][x].entity.pointer[1], self.tiles[y][x].entity.pointer[2])
				error("infinitely repeating getEntity at "..x.." "..y) 
			end
			return self:getEntity(
				self.tiles[y][x].entity.pointer[1],
				self.tiles[y][x].entity.pointer[2],
				type, 1
			)
		end
		if self.tiles[y][x].entity.key == "" then return nil end
		if type == "key" then
			return self.tiles[y][x].entity.key
		end

		if self.entities[self.tiles[y][x].entity.key] == nil then
			error("pointer to nil entity")
		end
		return self.entities[self.tiles[y][x].entity.key]
	end

	return room
end

local room = newRoom(8, 8)
room.tiles[2][2].value, room.tiles[2][2].canWalk = 1, false
room:addEntity("test", 1, 1)

local mouse = {
	x = 1,
	absx = 1,
	y = 1,
	absy = 1,
}

function love.update(dt)
	mouse.absx = math.floor(love.mouse.getX() / gl.windowScale)
	mouse.absy = math.floor(love.mouse.getY() / gl.windowScale)
	
	--mouse.x = math.floor(mouse.absx / gl.cellSize) + 1
	--mouse.y = math.floor(mouse.absy / gl.cellSize) + 1
	mouse.x, mouse.y = gl.getIsoCoords(mouse.absx, mouse.absy, true)
end
function love.keypressed(key)
	if key == "f" then
		gl.camera.x = gl.camera.x + 1
	end
	if key == "s" then
		gl.camera.x = gl.camera.x - 1
	end
	if key == "d" then
		gl.camera.y = gl.camera.y + 1
	end
	if key == "e" then
		gl.camera.y = gl.camera.y - 1
	end
end

local fullCanvas = love.graphics.newCanvas(gl.windowWidth, gl.windowHeight)
love.graphics.setLineWidth(1)

function love.draw()
	love.graphics.setCanvas(fullCanvas)
	love.graphics.clear()
	
	a.tiles.batch:clear()
	for y = 1, room.height do
		for x = 1, room.width do
			a.tiles.batch:add(a.tiles.quads[room.tiles[y][x].value][room.tiles[y][x].type],
				(gl.getScrCoords(x, y).x - 1) * gl.cellSize, 
				(gl.getScrCoords(x, y).y - 1) * gl.cellSize
			)
		end
	end
	love.graphics.draw(a.tiles.batch, 
		gl.gridStartingX + (gl.camera.x * gl.cellSize * 2), 
		gl.gridStartingY + (gl.camera.y * gl.cellSize)
	)

	love.graphics.draw(a.cursor, 
		(gl.getScrCoords(mouse.x, mouse.y).x - 1) * gl.cellSize + gl.gridStartingX + (gl.camera.x * gl.cellSize * 2),
		(gl.getScrCoords(mouse.x, mouse.y).y - 1) * gl.cellSize + gl.gridStartingY + (gl.camera.y * gl.cellSize)
	)
	
	if room:getEntity(mouse.x, mouse.y) then
		love.graphics.print(
			room:getEntity(mouse.x, mouse.y).check,
			0, room.height * gl.cellSize
		)
	end
	love.graphics.print(mouse.x.." "..mouse.y, 0, 0)
	
	love.graphics.setCanvas()
	love.graphics.draw(fullCanvas, 0, 0, 0, gl.windowScale, gl.windowScale)
end

