class Task
	constructor: (@id) ->
	getID: -> @id

class Channel
	constructor: (@id, @channelDistributionFunction) ->
		@status = 0
		@processedTasksNumber = 0
	getID: -> @id
	getStatus: -> @status
	getProcessedTasksNumber: -> @processedTasksNumber
	takeTask: ->
		if not @status 
			@status = 1
			that = @
			setTimeout ->
				that.status = 0
				that.processedTasksNumber++
			, @channelDistributionFunction()
			return true
		return false

class TaskManager
	constructor: (@channels, @isDebug = false) ->
		@numberOfLostTasks = 0
	spreadTask: (task) ->
		wasTaken = false
		for channel in @channels
			if channel.takeTask(task)
				if @isDebug 
					console.log "%c channel #{channel.getID()} take task #{task.getID()} ", 'background:#00C851; color: white'
				wasTaken = true
				break
		if not wasTaken 
			@numberOfLostTasks++
			if @isDebug 
				console.log "%c #{task.getID()} is lost ", 'background:#ffbb33; color: white'
	showStatistics: ->
		console.log "%c ============================================= ", 'background:#33b5e5; color: white'
		console.log "%c                     SUMMARY                   ", 'background:#33b5e5; color: white'
		console.log "%c ============================================= ", 'background:#33b5e5; color: white'
		tasksCount = 0
		countProcessedTasks = 0
		for channel in @channels
			console.log "%c channel #{channel.getID()} processed #{channel.getProcessedTasksNumber()} tasks ", 'background:#00C851; color: white'
			countProcessedTasks += channel.getProcessedTasksNumber() 
		tasksCount = countProcessedTasks + @numberOfLostTasks 
		probability = @numberOfLostTasks / tasksCount
		console.log  "%c #{@numberOfLostTasks} was lost ", 'background:#ffbb33; color: white'
		console.log  "%c Probability of failure - #{probability.toFixed(3)} ", 'background:#ff4444; color: white'

class Source
	constructor: (@taskManager) ->
		@onDone = new Rx.Subject()
	activate: (tasksCount, sourceDistributionFunction) ->
		count = tasksCount
		that = @
		handle = ->
			if count > 0 
				that.taskManager.spreadTask(new Task(count))
				timeout = setTimeout(handle, sourceDistributionFunction())
				count--
			else
				that.onDone.next()
		handle()

class QueuingSystem
	constructor: (@tasksCount, @channelDistributionFunction, @sourceDistributionFunction, @isDebugMode) ->
	start: ->
		channels = []
		for id in [1,2,3,4]
			channels.push(new Channel(id, @channelDistributionFunction))
		taskManager = new TaskManager(channels, @isDebugMode)
		source = new Source(taskManager)
		source.activate(@tasksCount, @sourceDistributionFunction)
		source.onDone.subscribe  ->
			setTimeout ->
				taskManager.showStatistics()
			, 300

isDebugMode = true
tasksCount = 100
channelDistributionFunction = ->
	channelIntensity = (0.6 / 4)
	(-1 / channelIntensity) * Math.log(Math.random(), Math.E) * 10
sourceDistributionFunction = ->
	sourceIntensity = 0.75
	(-1 / sourceIntensity) * Math.log(Math.random(), Math.E) * 10

queuingSystem = new QueuingSystem(tasksCount, channelDistributionFunction, sourceDistributionFunction, isDebugMode)
queuingSystem.start()