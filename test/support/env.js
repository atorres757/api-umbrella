'use strict';

var apiUmbrellaConfig = require('api-umbrella-config'),
    path = require('path');

var config = apiUmbrellaConfig.load(path.resolve(__dirname, '../config/test.yml'));

process.env.NODE_ENV = 'test';
process.env.API_UMBRELLA_LOG_LEVEL = 'debug';
process.env.API_UMBRELLA_LOG_PATH = path.join(config.get('log_dir'), 'test.log');
