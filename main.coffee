class Task
	constructor: (@id) ->
	getID: -> @id

class Channel
	constructor: (@id, @channelDistributionFunction) ->
		@status = 0
		@processedTasksNumber = 0
		@totalProcessingTime = 0
	getID: -> @id
	getStatus: -> @status
	getProcessedTasksNumber: -> @processedTasksNumber
	getTotalProcessingTime: -> @totalProcessingTime
	takeTask: ->
		if not @status 
			@status = 1
			that = @
			@totalProcessingTime += processingTime = @channelDistributionFunction()
			setTimeout ->
				that.status = 0
				that.processedTasksNumber++
			, processingTime
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
	getStatistics: ->
		tasksCount = 0
		countProcessedTasks = 0
		channelsStatistics = []
		for channel in @channels
			channelsStatistics.push {
				channelID: channel.getID()
				channelProcessedTasksNumber: channel.getProcessedTasksNumber(),
				channelTotalProcessingTime: channel.getTotalProcessingTime().toFixed(3)
			}
			countProcessedTasks += channel.getProcessedTasksNumber() 
		tasksCount = countProcessedTasks + @numberOfLostTasks 
		probability = @numberOfLostTasks / tasksCount
		return {
			channelsStatistics: channelsStatistics
			probability: probability.toFixed(3)
		}


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
	constructor: (@systemName, @tasksCount, @channelDistributionFunction, @sourceDistributionFunction, @isDebugMode) ->
		@onDone = new Rx.Subject()
	start: ->
		that = @
		channels = []
		for id in [1..4]
			channels.push(new Channel(id, @channelDistributionFunction))
		taskManager = new TaskManager(channels, @isDebugMode)
		source = new Source(taskManager)
		source.activate(@tasksCount, @sourceDistributionFunction)
		source.onDone.subscribe ->
			blueConsole = 'background:#33b5e5; color: white'
			greenConsole = 'background:#00C851; color: white'
			redConsole = 'background:#ff4444; color: white'
			setTimeout ->
				console.log "%c ============================================= ", blueConsole
				console.log "%c                   SYSTEM №#{that.systemName}                   ", blueConsole
				console.log "%c ============================================= ", blueConsole
				statistics = taskManager.getStatistics()
				for channelsStatistic in statistics.channelsStatistics
					console.log "%c channel #{channelsStatistic.channelID}
					 processed #{channelsStatistic.channelProcessedTasksNumber} tasks
					 by #{channelsStatistic.channelTotalProcessingTime} ms", greenConsole
				console.log "%c Probability of failure is #{statistics.probability} ", redConsole
				that.onDone.next({
					systemName: that.systemName
					probabilityFailure: statistics.probability
				})
			, 300
		
class SystemFactory
	constructor: (@tasksCount, @channelDistributionFunction, @sourceDistributionFunction, @onDoneHandle, @isDebugMode) ->
	getSystem: (systemName) ->
		queuingSystem = new QueuingSystem(systemName, @tasksCount, @channelDistributionFunction, @sourceDistributionFunction, @isDebugMode)
		that = @
		queuingSystem.onDone.subscribe (data) -> that.onDoneHandle(data)
		return queuingSystem

class ChannelDistributionFunctionFactiry
	getFunction: (channelIntensity) ->
		(_channelIntensity = channelIntensity) -> 
			(-1 / _channelIntensity) * Math.log(Math.random(), Math.E) 

class SourceDistributionFunctionFactiry
	getFunction: (sourceIntensity) ->
		(_sourceIntensity = @sourceIntensity) -> 
			(-1 / _sourceIntensity) * Math.log(Math.random(), Math.E) 


isDebugMode = false
tasksCount = 100
systemsCount = 5
channelIntensity = (0.6 / (4 * 3))
sourceIntensity = 0.75

onShortSystemsInfoCollectedForProbabilityFalureChart = new Rx.Subject()

onDoneGettingInfoForProbabilityFalureChartHandle = (data) ->
	if not @shortSystemsInfo
		@shortSystemsInfo = []
	@shortSystemsInfo.push data
	if @shortSystemsInfo.length is systemsCount
		onShortSystemsInfoCollectedForProbabilityFalureChart.next(@shortSystemsInfo)
	return @
onDoneGettingInfoForProbabilityFalureChartHandle.shortSystemsInfo = []

channelDistributionFunctionFactiry = new ChannelDistributionFunctionFactiry()
channelDistributionFunction = channelDistributionFunctionFactiry.getFunction(channelIntensity)

sourceDistributionFunctionFactiry = new SourceDistributionFunctionFactiry()
sourceDistributionFunction = sourceDistributionFunctionFactiry.getFunction(sourceIntensity)

systemFactory = new SystemFactory(tasksCount, channelDistributionFunction, sourceDistributionFunction, onDoneGettingInfoForProbabilityFalureChartHandle, isDebugMode)

for systemName in [1..systemsCount]
	systemFactory
	.getSystem(systemName)
	.start()

onShortSystemsInfoCollectedForProbabilityFalureChart.subscribe (shortSystemsInfo) ->
	$('.charts').removeClass 'hidden'
	$('.loader').addClass 'hidden'
	systemNames = []
	probabilityFailures = []
	shortSystemsInfo.sort (a, b) -> a.systemName - b.systemName
	for shortSystemInfo in shortSystemsInfo
		systemNames.push shortSystemInfo.systemName
		probabilityFailures.push +shortSystemInfo.probabilityFailure
	probabilityFailureChart = new Chartist.Line '.probability-failure-chart',
	{
		labels: [systemNames...]
		series: [[probabilityFailures...]]
	},
	{
		fullWidth: true
		lineSmooth: Chartist.Interpolation.cardinal { fillHoles: true }
		low: 0
		high: 1
	}

initialSourceIntensity = 0.75
finalSourceIntensity = 12.1
deltaSourceIntensity = 0.15

onShortSystemsInfoCollectedForDeltaSourceChart = new Rx.Subject()

onDoneGettingInfoForDeltaSourceChartHandle = (data) ->
	if not @shortSystemsInfo
		@shortSystemsInfo = []
	@shortSystemsInfo.push data
	if @shortSystemsInfo.length > 50 #исправить!
		onShortSystemsInfoCollectedForDeltaSourceChart.next(@shortSystemsInfo)
	return @
onDoneGettingInfoForDeltaSourceChartHandle.shortSystemsInfo = []

deltaSourceSystemIndex = 0
for changingSourceIntensity in [initialSourceIntensity..finalSourceIntensity] by deltaSourceIntensity
	new SystemFactory(tasksCount,
										channelDistributionFunctionFactiry.getFunction(channelIntensity),
										sourceDistributionFunctionFactiry.getFunction(changingSourceIntensity),
										onDoneGettingInfoForDeltaSourceChartHandle)
										.getSystem(++deltaSourceSystemIndex)
										.start()

onShortSystemsInfoCollectedForDeltaSourceChart.subscribe (shortSystemsInfo) ->
	systemNames = []
	probabilityFailures = []
	shortSystemsInfo.sort (a, b) -> a.systemName - b.systemName
	for shortSystemInfo in shortSystemsInfo
		systemNames.push shortSystemInfo.systemName
		probabilityFailures.push +shortSystemInfo.probabilityFailure
	deltaSourceChart = new Chartist.Line '.delta-source-chart',
	{
		labels: [systemNames...]
		series: [[probabilityFailures...]]
	},
	{
		fullWidth: true
		lineSmooth: Chartist.Interpolation.cardinal { fillHoles: true }
		low: 0
		high: 1
	}


