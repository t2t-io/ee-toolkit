#
# Copyright (c) 2019-2020 T2T Inc. All rights reserved
# https://www.t2t.io
# Taipei, Taiwan
#
require! <[fs path]>
{execSync} = require \child_process
parse = require \csv-parse/lib/sync

DBG = (message) ->
  return console.log message if global.verbose

ERR = (message) ->
  return console.error message

COMPARE_ID = (a, b) ->
  return -1 if a.prefix < b.prefix
  return 1 if a.prefix > b.prefix
  return -1 if a.index < b.index
  return 1 if a.index > b.index
  return 0

COMPARE_COMP = (a, b) ->
  return COMPARE_ID a.id, b.id

ROW2OBJ = (headers, data) ->
  xs = {[headers[i], x] for let x, i in data}
  return xs



class IdString
  (@value) ->
    self = @
    self.test1 value
    xs = value.match /^[a-zA-Z]+/
    return self.parse-number! unless xs?
    return self.parse xs[0]

  test1: (v) ->
    return if /^[a-zA-Z]*[0-9]+$/ .test v
    console.log "invalid Id string: #{id}"
    return process.exit 2

  parse-number: ->
    {value} = self = @
    self.prefix = ''
    self.postfix = value
    self.index = parseInt value

  parse: (@prefix) ->
    {value} = self = @
    self.postfix = value.substring prefix.length
    self.index = parseInt self.postfix
    


class Component
  (@parent, @headers, @lineno, @vs) ->
    {Refs, value} = @data = ROW2OBJ headers, vs
    @parent.add_error "line #{lineno}: missing Refs field" unless Refs?
    @parent.add_error "line #{lineno}: missing value field" unless value?
    @parent.add_error "line #{lineno}: (#{Refs}) value field isn't a string, but #{typeof value}" unless \string is typeof value
    @ref = Refs
    @value = value
    @id = new IdString @ref

  ##
  # Valid capacitor values:
  #   - 0.1uF/16V/0402
  #   - 4.7uF/6.3V/0603
  #   - 0.1uF/NC/NC
  #
  #
  check_capacitor: ->
    {id, ref, value, parent} = self = @
    {prefix} = id
    return unless prefix is \C
    tokens = value.split '/'
    return parent.add_warning "#{ref.cyan}: value (#{value.yellow}) must be 3 tokens but only #{tokens.length}" unless tokens.length >= 3
    [cpacitance, voltage, pkg] = tokens
    xs = cpacitance.match /^[0-9\.]+[a-z]*F/
    parent.add_warning "#{ref.cyan}: cpacitance in value (#{value.yellow}) is invalid, with regexp /^[0-9\\.]+[a-z]*F/" unless xs?
    xs = voltage.match /^[0-9\.]+[K]?V/
    parent.add_warning "#{ref.cyan}: voltage (#{voltage.red}) in value (#{value.yellow}) is invalid, with regexp /^[0-9\.]+[K]?V/, e.g. 220V, 1KV, 3.3V, or NC" unless (xs? or (\NC is voltage))
    return

  ##
  # Valid jumper (connector-pin-header) values
  #   - 1x03_2.00mm
  #   - 1x03_2.00mm
  #   - 1x06_2.54mm
  #
  check_jumper: ->
    {id, ref, value, data, parent} = self = @
    {prefix} = id
    {footprint} = data
    return unless prefix is \J
    return unless footprint.startsWith "Connector_PinHeader"
    # console.log "#{ref.cyan} => #{value.green} => #{footprint.red}"
    return parent.add_warning "#{ref.cyan}: special value (#{value.yellow})" unless /^[1-9][0-9]*x[0-9][0-9]_[0-9\.]+mm/ .test value
    # tokens = value.split '_'
    # {composition,pitch}

  ##
  # Valid resistor values:
  #   - 
  #
  check_resistor: ->
    {id, ref, value, parent} = self = @
    {prefix} = id
    return unless prefix is \R
    tokens = value.split '/'
    return parent.add_warning "#{ref.cyan}: value (#{value.yellow}) must be 3 tokens but only #{tokens.length}" unless tokens.length >= 2
    [resistance, tolerance, pkg] = tokens
    xs = resistance.match /^[0-9\.]+[KR]$/
    parent.add_warning "#{ref.cyan}: resistance (#{resistance.red}) in value (#{value.yellow}) is invalid, with regexp /^[0-9\.]+[KR]/, e.g. 0R, 40.2K, 330R" unless xs?
    xs = tolerance.match /^[0-9]+%$/
    parent.add_warning "#{ref.cyan}: tolerance (#{tolerance.red}) in value (#{value.yellow}) is invalid, with regexp /^[0-9]+%$/, e.g. 1%, 5%, 10% or NC" unless (xs? or (\NC is tolerance))


class Manager
  (@opts, @headers, @csv) ->
    @errors = []
    @warnings = []
    self = @
    {input} = opts
    self.name = path.basename input
    xs = [ (new Component self, headers, i + 1, x) for let x, i in csv ]
    xs.sort COMPARE_COMP
    self.components = xs
    self.check_error!
    # for c in xs
    #  console.log "#{c.ref}: #{c.id.prefix} #{c.id.index} => #{c.value.yellow}"

  add_error: (e) -> return @errors.push e
  add_warning: (w) -> return @warnings.push w

  check_error: ->
    {errors, opts} = self = @
    return unless errors.length > 0
    self.print_warnings!
    console.log "[#{name.magenta}] found errorrs:"
    for e in errors
      console.log "\t#{e.red}"
    return process.exit 1

  print_warnings: ->
    {warnings, name} = self = @
    return unless warnings.length > 0
    console.log "[#{name.magenta}] found warnings:"
    for w in warnings
      console.log "\t#{w}"

  check_component_value: ->
    {components} = self = @
    [ (c.check_capacitor!) for c in components ]
    [ (c.check_resistor!) for c in components ]
    [ (c.check_jumper!) for c in components ]


module.exports = exports =
  command: "bom-linter"
  describe: "review bom components"

  builder: (yargs) ->
    yargs
      .alias 'i', 'input'
      .describe 'i', 'the input schematic file'
      .alias 'h', 'help'
      .alias 'v', 'verbose'
      .describe 'v', 'verbose message output'
      .default 'v', no
      .demand <[i v]>
      .epilogue """
        For example:
          #{path.basename process.argv[1]} bom-linter -i ./mainboard.sch
      """

  handler: (argv) ->
    {input, verbose} = argv
    global.verbose = verbose
    DBG "input = #{input.yellow}"
    csvfile = "/tmp/#{path.basename input}.csv"
    try
      ret = execSync "kifield --help"
      DBG "found kifield"
    catch e
      ERR "missing kifield tool. please use pip to install it"
      process.exit 1

    try
      ret = execSync "kifield -x #{input} -i #{csvfile}"
      DBG "successfully extract bom from #{input.yellow} with kifield"
    catch e
      ERR "failed to extract bom"
      ERR e
      process.exit 1

    try
      buffer = fs.readFileSync csvfile
      DBG "successfully read the content of csvfile: #{csvfile.yellow}"
    catch e
      ERR "failed to read csvfile content"
      ERR e
      process.exit 1

    csv = parse buffer.toString!
    headers = csv.shift!
    manager = new Manager {input}, headers, csv
    manager.check_component_value!
    manager.check_error!
    manager.print_warnings!

