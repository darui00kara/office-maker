var url = require('url');
var express = require('express');
var app = express();
var bodyParser = require('body-parser');
var fs = require('fs');
var path = require('path');
var ejs = require('ejs');
var request = require('request');
var jwt = require('jsonwebtoken');
var filestorage = require('./lib/filestorage.js');
var db = require('./lib/db.js');
var rdb = require('./lib/mysql.js');
var accountService = require('./lib/account-service');
var profileService = require('./lib/profile-service');
var log = require('./lib/log.js');

var config = null;
if(fs.existsSync(__dirname + '/config.json')) {
  config = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
} else {
  config = JSON.parse(fs.readFileSync(__dirname + '/defaultConfig.json', 'utf8'));
}
config.apiRoot = '/api';
config.secret = fs.readFileSync(path.resolve(__dirname, config.secret), 'utf8');

var rdbEnv = rdb.createEnv(config.mysql.host, config.mysql.user, config.mysql.pass, 'map2');

var publicDir = __dirname + '/public';

app.use(log.express);
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: false }));

function inTransaction(f) {
  return function(req, res) {
    rdbEnv.forConnectionAndTransaction((conn) => {
      return f(conn, req, res);
    }).then((data) => {
      res.send(data);
    }).catch((e) => {
      if(typeof e === 'number' && e >= 400) {
        res.status(e).send('');
      } else {
        log.system.error('error', e);
        log.system.error(e.stack);
        res.status(500).send('');
      }
    });
  }
}

function getAuthToken(req) {
  return req.headers['authorization'];
}

function getSelf(conn, token) {
  if(!token) {
    if(config.multiTenency) {
      return Promise.reject(403);
    } else {
      return Promise.resolve(null);
    }
  }
  return new Promise((resolve, reject) => {
    jwt.verify(token, config.secret, {
      algorithms: ['RS256', 'RS384', 'RS512', 'HS256', 'HS256', 'HS512', 'ES256', 'ES384', 'ES512']
    }, (e, user) => {
      if (e) {
        reject(e);
      } else {
        user.id = user.id || user.userId;
        user.role = user.role.toLowerCase();
        user.tenantId = '';
        resolve(user);
      }
    });
  }).catch((e) => {
    log.system.debug(e);
    Promise.reject(401);
    // if(e.name === 'JsonWebTokenError') {
    //   return Promise.reject(401);
    // } else {
    //   return Promise.reject(e);
    // }
  });
}

app.use(express.static(publicDir));

var templateDir = __dirname + '/template';
var indexHtml = ejs.render(fs.readFileSync(templateDir + '/index.html', 'utf8'), {
  apiRoot: config.apiRoot,
  accountServiceRoot: config.accountServiceRoot,
  title: config.title
});
var loginHtml = ejs.render(fs.readFileSync(templateDir + '/login.html', 'utf8'), {
  accountServiceRoot: config.accountServiceRoot,
  title: config.title
});
var masterHtml = ejs.render(fs.readFileSync(templateDir + '/master.html', 'utf8'), {
  apiRoot: config.apiRoot,
  accountServiceRoot: config.accountServiceRoot,
  title: config.title
});

app.get('/', (req, res) => {
  res.send(indexHtml);
});

app.get('/login', (req, res) => {
  res.send(loginHtml);
});

app.get('/logout', (req, res) => {
  res.redirect('/login');
});

app.get('/master', (req, res) => {
  res.send(masterHtml);
});

app.get('/api/1/people/:id', inTransaction((conn, req, res) => {
  var token = getAuthToken(req);
  var id = req.params.id;
  return getSelf(conn, token).then((user) => {
    return profileService.getPerson(config.profileServiceRoot, token, id).then((person) => {
      if(!person) {
        return Promise.reject(404);
      }
      return Promise.resolve(person);
    });
  });
}));

app.get('/api/1/people', inTransaction((conn, req, res) => {
  var token = getAuthToken(req);
  var options = url.parse(req.url, true).query;
  var floorId = options.floorId;
  var floorVersion = options.floorVersion;
  var postName = options.post;
  if(!floorId || !floorVersion || !postName) {
    return Promise.reject(400);
  }
  return getSelf(conn, token).then((user) => {
    return db.getFloorOfVersionWithObjects(conn, user.tenantId, floorId, floorVersion).then((floor) => {
      var peopleSet = {};
      floor.objects.forEach((object) => {
        if (object.personId) {
          peopleSet[object.personId] = true;
        }
      });
      return profileService.getPeopleByPost(config.profileServiceRoot, token, postName).then((people) => {
        return Promise.resolve(people.filter((person) => {
          return peopleSet[person.id];
        }));
      });
    });
  });
}));

app.get('/api/1/self', inTransaction((conn, req, res) => {
  var token = getAuthToken(req);
  if(!token) {
    return Promise.resolve({});
  }
  return getSelf(conn, token).then((user) => {
    if(!user) {
      return Promise.resolve({
        role: 'guest',
      });
    }
    return profileService.getPerson(config.profileServiceRoot, token, user.id).then((person) => {
      if(person == null) {
        throw "Relevant person for " + user.id + " not ound."
      }
      user.person = person;
      return Promise.resolve(user);
    });
  });
}));

// should be person?
app.get('/api/1/users/:id', inTransaction((conn, req, res) => {
  var token = getAuthToken(req);
  var userId = req.params.id;
  return getSelf(conn, token).then((user) => {
    return profileService.getPerson(config.profileServiceRoot, token, userId).then((person) => {
      user.person = person//FIXME should not
      return Promise.resolve(user);
    });
  });
}));

app.get('/api/1/prototypes', inTransaction((conn, req, res) => {
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user) {
      return Promise.reject(403);
    }
    return db.getPrototypes(conn, user.tenantId).then((prototypes) => {
      return Promise.resolve(prototypes);
    });
  });
}));

app.put('/api/1/prototypes', inTransaction((conn, req, res) => {
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user) {
      return Promise.reject(403);
    }
    var prototypes = req.body;
    if(!prototypes || !prototypes.length) {
      return Promise.reject(403);
    }
    return db.savePrototypes(conn, user.tenantId, prototypes).then(() => {
      return Promise.resolve({});
    });
  })
}));

app.get('/api/1/colors', inTransaction((conn, req, res) => {
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user) {
      return Promise.reject(403);
    }
    return db.getColors(conn, user.tenantId).then((colors) => {
      return Promise.resolve(colors);
    });
  })
}));

app.put('/api/1/colors', inTransaction((conn, req, res) => {
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user) {
      return Promise.reject(403);
    }
    var colors = req.body;
    if(!colors || !colors.length) {
      return Promise.reject(403);
    }
    return db.saveColors(conn, user.tenantId, colors).then(() => {
      return Promise.resolve({});
    });
  });
}));

app.get('/api/1/floors', inTransaction((conn, req, res) => {
  var options = url.parse(req.url, true).query;
  return getSelf(conn, getAuthToken(req)).then((user) => {
    var tenantId = user ? user.tenantId : '';
    return db.getFloorsInfo(conn, tenantId).then((floorInfoList) => {
      return Promise.resolve(floorInfoList);
    });
  });
}));

// admin only
app.get('/api/1/floors/:id/:version', inTransaction((conn, req, res) => {
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user || user.role !== 'admin') {
      return Promise.reject(403);
    }
    var tenantId = user ? user.tenantId : '';
    var id = req.params.id;
    var version = req.params.version;
    log.system.debug('get: ' + id + '/' + version);
    return db.getFloorOfVersionWithObjects(conn, tenantId, id, version).then((floor) => {
      if(!floor) {
        return Promise.reject(404);
      }
      log.system.debug('gotFloor: ' + id + '/' + version + ' ' + floor.objects.length);
      return Promise.resolve(floor);
    })
  });
}));

app.get('/api/1/floors/:id', inTransaction((conn, req, res) => {
  var options = url.parse(req.url, true).query;
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user && options.all) {
      return Promise.reject(403);
    }
    var tenantId = user ? user.tenantId : '';
    var id = req.params.id;
    log.system.debug('get: ' + id);
    return db.getFloorWithObjects(conn, tenantId, options.all, id).then((floor) => {
      if(!floor) {
        return Promise.reject(404);
      }
      log.system.debug('gotFloor: ' + id + ' ' + floor.objects.length);
      return Promise.resolve(floor);
    })
  });
}));

app.get('/api/1/search/:query', inTransaction((conn, req, res) => {
  var token = getAuthToken(req);
  var options = url.parse(req.url, true).query;
  var query = req.params.query;
  return getSelf(conn, token).then((user) => {
    return profileService.search(config.profileServiceRoot, token, query).then((people) => {
      return db.search(conn, user.tenantId, query, options.all, people);
    });
  });
}));

app.get('/api/1/candidates/:name', inTransaction((conn, req, res) => {
  var token = getAuthToken(req);
  var name = req.params.name;
  return profileService.search(config.profileServiceRoot, token, name);
}));

// TODO move to service logic
function isValidFloor(floor) {
  if(!floor.name.trim()) {
    return false;
  }
  return true;
}
app.put('/api/1/floors/:id', inTransaction((conn, req, res) => {
  return getSelf(conn, getAuthToken(req)).then((user) => {
    if(!user) {
      return Promise.reject(403);
    }
    var newFloor = req.body;
    if(newFloor.id && req.params.id !== newFloor.id) {
      return Promise.reject(400);
    }
    if(!isValidFloor(newFloor)) {
      return Promise.reject(400);
    }
    var updateBy = user.id;
    return db.saveFloorWithObjects(conn, user.tenantId, newFloor, updateBy).then((floor) => {
      log.system.debug('saved floor: ' + floor.id);
      return Promise.resolve(floor);
    });
  });
}));

// publish
app.put('/api/1/floors/:id/public', inTransaction((conn, req, res) => {
  var token = getAuthToken(req)
  return getSelf(conn, token).then((user) => {
    if(!user || user.role !== 'admin') {
      return Promise.reject(403);
    }
    var id = req.params.id;
    var updateBy = user.id;
    return db.publishFloor(conn, user.tenantId, id, updateBy).then((floor) => {
      log.system.info('published floor: ' + floor.id + '/' + floor.version);
      return Promise.resolve(floor);
    });
  });
}));

app.delete('/api/1/floors/:id', inTransaction((conn, req, res) => {
  var token = getAuthToken(req)
  return getSelf(conn, token).then((user) => {
    if(!user || user.role !== 'admin') {
      return Promise.reject(403);
    }
    var id = req.params.id;
    var updateBy = user.id;
    return db.deleteFloor(conn, user.tenantId, id).then(() => {
      log.system.info('deleted floor');
      return Promise.resolve();
    });
  });
}));

app.put('/api/1/images/:id', inTransaction((conn, req, res) => {
  return new Promise((resolve, reject) => {
    getSelf(conn, getAuthToken(req)).then((user) => {
      if(!user || user.role !== 'admin') {
        return reject(403);
      }
      var id = req.params.id;
      var all = [];
      req.on('data', (data) => {
        all.push(data);
      });
      req.on('end', () => {
        var image = Buffer.concat(all);
        db.saveImage(conn, 'images/floors/' + id, image).then(() => {
          // res.end();
          resolve({});
        }).catch(reject);
      })
    });
  });
}));

process.on('uncaughtException', (e) => {
  log.system.error('uncaughtException');
  log.system.error(e.stack);
});

var port = 3000;
app.listen(port, () => {
  log.system.info('server listening on port ' + port + '.');
});
