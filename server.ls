#!/usr/bin/env lsc

require! {
  express
  'express-session': session
  'body-parser'
  'fs'
  'https'
  './user.ls'
  './app.ls'
  './config.json'
}

credentials = false;
if fs.existsSync "/run/secrets/DATABOX.pem"
  credentials = {}
  credentials.key =  fs.readFileSync "/run/secrets/DATABOX.pem"
  credentials.cert = fs.readFileSync "/run/secrets/DATABOX.pem"

handlers = { user, app }

app = express!

app.enable 'trust proxy'

#err, data <-! fs.read-file 'data/session-cookie-keys.txt', encoding: \utf8

app.use session do
  resave: false
  save-uninitialized: false
  secret: \datashop

app.use body-parser.urlencoded extended: false

#app.use express.static 'static'
app.set \views \views
app.set 'view engine' \jade

app.get \/ (req, res) !->
  unless req.session.user?
    unless process.env.LOCAL_MODE?
      res.render \login { config: config }
      return
    req.session.user =
      _id: -1
      username: \localuser

  res.render \dashboard { user: req.session.user }

handle = (req, res, data) !->
  api  = req.params.api
  call = req.params.call

  unless api? and call?
    res.write-head 400
    res.end!
    return

  unless api of handlers and call of handlers[api]
    res.write-head 404
    res.end!
    return

  data.ip = req.ip
  out = {} <-! handlers[api][call] req.session, data

  if out.redirect?
    res.redirect out.redirect
    return
  res.write-head 200,
    \Access-Control-Allow-Origin : req.headers.origin or \*
    \Content-Type : \application/json
  res.end JSON.stringify out

app.get  \/:api/:call (req, res) !-> handle req, res, req.query

app.post \/:api/:call (req, res) !-> handle req, res, req.body

app.post '/400' (req, res) !->
  res.write-head 400
  res.end!

done = (tmp) !->
  console.log "listening on" + process.env.PORT + " https !!"

if credentials === false
  app.listen (process.env.PORT or 8080)
else
  console.log credentials
  server = https.createServer credentials, app
  server.listen process.env.PORT, done
