const { build, install } = require('./test/helpers')

build('library-exports')
build('library-exports', {
  name: 'library-exports in a path with a comma',
  build: 'build/comma, path'
})
build('executable-exports')
build('executable-exports', {
  name: 'executable-exports in a path with a comma',
  build: 'build/comma, path'
})
install('package/producer', 'package/consumer', { name: 'package' })
