###
 rechnung-couch
 https://github.com/lordnox/rechnung-couch

 Copyright (c) 2013 Tobias Kopelke
 Licensed under the MIT license.
###

'use strict';

uuid = -> 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
  r = Math.random()*16|0
  v = if c is 'x' then r else r&0x3|0x8
  return v.toString 16;

configuration =
  steuer: .19

class Rechnung
  constructor: (@rechnungsnummer, @adresse = [], @datum, einheiten, inklusive, @_rev) ->
    throw new Error 'rechnungsnummer required' if not @rechnungsnummer
    @id             = @rechnungsnummer or uuid()
    @inklusive      = if inklusive is undefined then true else !!inklusive
    @state          = Rechnung.states.created
    einheiten       = [] if not Array.isArray einheiten
    @einheiten      = einheiten.map (einheit) -> Einheit.createFromCouchSync einheit

  add: (einheit) ->
    @einheiten.push einheit

  summe: ->
    result = @einheiten.reduce (sum, einheit) ->
      sum + einheit.summe()
    , 0
    result *= (1 + configuration.steuer) if not @inklusive
    result

  summeSteuern: ->
    @summe() / (1 + configuration.steuer)

  equal: (rechnung, revision = true) ->
    return false if revision and @_rev isnt rechnung._rev
    return false if @adresse.length isnt rechnung.adresse.length
    return false if @einheiten.length isnt rechnung.einheiten.length
    index = @adresse.length
    while index--
      return false if @adresse[index] isnt rechnung.adresse[index]
    index = @einheiten.length
    while index--
      return false if not @einheiten[index].equal rechnung.einheiten[index]
    @id is rechnung.id and
      @rechnungsnummer is rechnung.rechnungsnummer
      @datum is rechnung.datum
      @inklusive is rechnung.inklusive

  save: (db, fn) ->
    if not fn then return (fn) => @save db, fn
    create(db) @, fn

  send: (db, fn) ->
    if not fn then return (fn) => @send db, fn
    @state = Rechnung.states.send
    @save db, fn

  pay: (db, fn) ->
    if not fn then return (fn) => @pay db, fn
    @state = Rechnung.states.paid
    @save db, fn

  archive: (db, fn) ->
    if not fn then return (fn) => @archive db, fn
    @state = Rechnung.states.archived
    @save db, fn

Rechnung.createFromCouchSync = (body) ->
  rechnung = new Rechnung body.rechnungsnummer, body.adresse, body.datum, body.einheiten, body.inklusive, body._rev
  rechnung.state = body.state || rechnung.state
  rechnung

Rechnung.createFromCouch = (fn) -> (err, body) ->
  return fn err, body if err
  fn err, Rechnung.createFromCouchSync body

Rechnung.states =
  created : 'created'
  send    : 'send'
  paid    : 'paid'
  archived: 'archived'


class Einheit
  constructor: (@datum, @text, @menge, @preis) ->
    # Menge kann ein integer oder ein String sein,
    # @integer Anzahl dieser Einheit -> Summe = preis * menge
    # @string `Zeit` dieser Einheit -> Summe = preis/h * stunden(menge)

  summe: ->
    if typeof @menge is 'string'
      [hour, min] = @menge.split ':'
      menge = ((parseInt hour, 10) * 60 + (parseInt min, 10)) / 60
    else
      menge = parseInt @menge, 10
    menge * @preis

  equal: ->
    true

Einheit.createFromCouchSync = (body) -> new Einheit body.datum, body.text, body.menge, body.preis

create = (db) -> (rechnung, fn) ->
  db.insert rechnung, rechnung.id, (err, body) ->
    return fn err, body if err
    rechnung._rev = body.rev
    rechnung.id = body.id
    Rechnung.createFromCouch(fn) err, rechnung

read = (db) -> (rechnungsnummer, fn) ->
  if rechnungsnummer instanceof Rechnung
    rechnungsnummer = rechnungsnummer.rechnungsnummer

  db.get rechnungsnummer, Rechnung.createFromCouch fn

viewToRechnungen = (fn) -> (err, body) ->
  return fn err, body if err
  row = body.total_rows
  results = []
  while row--
    results[row] = Rechnung.createFromCouchSync body.rows[row].value
  fn null, results

retrieveView = (db, design, view) -> (params, fn) ->
  if(!fn)
    fn      = params
    params  = {}
  db.view design, view, params, viewToRechnungen fn

views =
  list      : (db) -> retrieveView db, 'rechnungCouch', 'listAll'
  onlyUnsend: (db) -> retrieveView db, 'rechnungCouch', 'onlyUnsend'
  onlyUnpaid: (db) -> retrieveView db, 'rechnungCouch', 'onlyUnpaid'
  onlyPaid  : (db) -> retrieveView db, 'rechnungCouch', 'onlyPaid'

rechnungCouch =
  Rechnung    : Rechnung
  Einheit     : Einheit
  connect     : (db) ->
    onlyUnsend  : views.onlyUnsend db
    onlyUnpaid  : views.onlyUnpaid db
    onlyPaid    : views.onlyPaid db
    list        : views.list db
    create      : create db
    read        : read db
    update      : create db # Same as create in couchDB

module.exports = rechnungCouch

