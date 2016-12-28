gulp				= require 'gulp'
less				= require 'gulp-less'
watch				= require 'gulp-watch'
stylus			= require 'gulp-stylus'
concat			= require 'gulp-concat'
coffee			= require 'gulp-coffee'
gulpIgnore	= require 'gulp-ignore'


gulp.task 'dev-js', ->
	gulp.src '*.coffee'
		.pipe gulpIgnore.exclude ['gulpfile.coffee']
		.pipe coffee() 
		.pipe gulp.dest './'

gulp.task 'dev-css', ['less'], ->
	gulp.src 'styles.styl'
		.pipe stylus({
			'include css': true,
			compress: true
		})
		.pipe gulp.dest './'

gulp.task 'less', ->
	gulp.src '*.less'
		.pipe less()
		.pipe gulp.dest './'

gulp.task 'watch', ->
	gulp.watch '*.coffee', ['dev-js']

