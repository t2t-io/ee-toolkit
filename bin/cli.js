#!/usr/bin/env node
/*
 * Copyright (c) 2019-2020 T2T Inc. All rights reserved
 * https://www.t2t.io
 * Taipei, Taiwan
 */
var livescript = require('livescript');
var yargs = require('yargs');
var colors = require('colors');

argv =
    yargs
        .alias('h', 'help')
        .command(require('../src/bom-linter'))
        .demand(1)
        .strict()
        .help()
        .argv;
