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
		source.onDone.subscribe ->
			blueConsole = 'background:#33b5e5; color: white'
			greenConsole = 'background:#00C851; color: white'
			redConsole = 'background:#ff4444; color: white'
			setTimeout ->
				console.log "%c ============================================= ", blueConsole
				console.log "%c                   #{that.systemName}                   ", blueConsole
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
		source.activate(@tasksCount, @sourceDistributionFunction)
		
class SystemFactory
	getSystem: (systemName, tasksCount, channelDistributionFunction, sourceDistributionFunction, onDoneHandle, isDebugMode = false) ->
		queuingSystem = new QueuingSystem(systemName, tasksCount, channelDistributionFunction, sourceDistributionFunction, isDebugMode)
		queuingSystem.onDone.subscribe (data) -> onDoneHandle(data)
		return queuingSystem

class ChannelDistributionFunctionFactory
	getFunction: (channelIntensity) ->
		(_channelIntensity = channelIntensity) -> 
			(-1 / _channelIntensity) * Math.log(Math.random(), Math.E) * 1

class SourceDistributionFunctionFactory
	getFunction: (sourceIntensity) ->
		(_sourceIntensity = sourceIntensity) -> 
			(-1 / _sourceIntensity) * Math.log(Math.random(), Math.E) * 1



####### shared data #######

systemFactory = new SystemFactory()

channelDistributionFunctionFactory = new ChannelDistributionFunctionFactory()

sourceDistributionFunctionFactory = new SourceDistributionFunctionFactory()

createChart = (chartName) ->
	new Chartist.Line ".#{chartName}", null, {
		fullWidth: true
		high: 1
		low: 0
	}

fillChart = (chart, data) ->
	systemNames = []
	probabilityFailures = []
	info = data
	info.sort (a, b) -> a.systemName - b.systemName
	for i in info
		systemNames.push i.systemName
		probabilityFailures.push i.probabilityFailure
	
	infoForUpdate = {
		labels: [systemNames...]
		series: [[probabilityFailures...]]
	}
	chart.update(infoForUpdate)


####### repetition experiment #######

isDebugMode = false
tasksCount = 150
systemsCount = 5
channelIntensity = 0.04
sourceIntensity = 1

probabilityFailureChart = {}
SSIForProbabilityFalureChart = []
onDoneGettingInfoForProbabilityFalureChartHandle = (data) ->
	$('.charts').removeClass 'hidden'
	$('.loader').addClass 'hidden'

	SSIForProbabilityFalureChart.push data
	if jQuery.isEmptyObject(probabilityFailureChart)
		probabilityFailureChart = createChart('probability-failure-chart')
	fillChart(probabilityFailureChart, SSIForProbabilityFalureChart)
	return @

$(".probability-failure-chart-info").text "[si = #{sourceIntensity}; ci = #{channelIntensity}]"
for systemName in [1..systemsCount]
	systemFactory
	.getSystem(systemName,
						 tasksCount,
						 channelDistributionFunctionFactory.getFunction(channelIntensity),
						 sourceDistributionFunctionFactory.getFunction(sourceIntensity),
						 onDoneGettingInfoForProbabilityFalureChartHandle,
						 isDebugMode)
	.start()



###### delta source experiment #######

initialSourceIntensity = 0.01
finalSourceIntensity = 0.2
deltaSourceIntensity = 0.025
channelIntensityForDeltasSurceExperiment = 0.01

deltaSourceChart = {}
SSIForDeltaSourceChart = []
onDoneGettingInfoForDeltaSourceChartHandle = (data) ->
	SSIForDeltaSourceChart.push data
	if jQuery.isEmptyObject(deltaSourceChart)
		deltaSourceChart = createChart('delta-source-chart')
	fillChart(deltaSourceChart, SSIForDeltaSourceChart)
	return @

$(".delta-source-chart-info").text "[si = from #{initialSourceIntensity} to #{finalSourceIntensity}; ci = #{channelIntensityForDeltasSurceExperiment}]"
for changingSourceIntensity in [initialSourceIntensity..finalSourceIntensity] by deltaSourceIntensity
	systemFactory
	.getSystem(changingSourceIntensity.toFixed(3),
						 tasksCount,
						 channelDistributionFunctionFactory.getFunction(channelIntensityForDeltasSurceExperiment),
						 sourceDistributionFunctionFactory.getFunction(changingSourceIntensity),
						 onDoneGettingInfoForDeltaSourceChartHandle)
	.start()



####### delta channel experiment #######

initialChannelIntensity = 0.01
finalChannelIntensity = 0.1
deltaChannelIntensity = 0.01
sourceIntensityForDeltaChannelExperiment = 1

deltaChannelChart = {}
SSIForDeltaChannelChart = []
onDoneGettingInfoForDeltaChannelChartHandle = (data) ->
	SSIForDeltaChannelChart.push data
	if jQuery.isEmptyObject(deltaChannelChart)
		deltaChannelChart = createChart('delta-channel-chart')
	fillChart(deltaChannelChart, SSIForDeltaChannelChart)
	return @

$(".delta-channel-chart-info").text "[si = #{sourceIntensityForDeltaChannelExperiment}; ci = from #{initialChannelIntensity} to #{finalChannelIntensity}]"
for changingChannelIntensity in [initialChannelIntensity..finalChannelIntensity] by deltaChannelIntensity
	if changingChannelIntensity > finalChannelIntensity
		break
	systemFactory
	.getSystem(changingChannelIntensity.toFixed(3),
						 tasksCount,
						 channelDistributionFunctionFactory.getFunction(changingChannelIntensity),
						 sourceDistributionFunctionFactory.getFunction(sourceIntensity),
						 onDoneGettingInfoForDeltaChannelChartHandle)
	.start()





