const test = require('brittle')
const path = require('path')
const make = require('bare-make')

const root = path.resolve(__dirname, '..')

async function compile(cwd, build, define = []) {
  await make.generate({
    cwd,
    source: '.',
    build,
    cache: false,
    define: [`cmake-prelude_DIR=${root}`, ...define],
    stdio: 'inherit'
  })

  await make.build({ cwd, build, clean: true, stdio: 'inherit' })
}

// Builds a fixture and runs the tests that it declares.
exports.build = function build(fixture, opts = {}) {
  const { name = fixture, build = 'build' } = opts

  test(name, { timeout: 300000 }, async (t) => {
    const cwd = path.resolve(__dirname, 'fixtures', fixture)

    await t.execution(async () => {
      await compile(cwd, build)

      await make.test({ cwd, build, stdio: 'inherit' })
    }, 'builds and passes its tests')
  })
}

// Installs a fixture as a package and runs the tests of a fixture that finds
// it.
exports.install = function install(producer, consumer, opts = {}) {
  const { name = producer } = opts

  test(name, { timeout: 300000 }, async (t) => {
    const cwd = path.resolve(__dirname, 'fixtures', producer)
    const prefix = path.join(cwd, 'prefix')

    await t.execution(async () => {
      await compile(cwd, 'build')

      await make.install({ cwd, build: 'build', prefix, stdio: 'inherit' })
    }, 'installs the package')

    const consumerCwd = path.resolve(__dirname, 'fixtures', consumer)

    await t.execution(async () => {
      await compile(consumerCwd, 'build', [`CMAKE_PREFIX_PATH=${prefix}`])

      await make.test({ cwd: consumerCwd, build: 'build', stdio: 'inherit' })
    }, 'finds the package and passes its tests')
  })
}
