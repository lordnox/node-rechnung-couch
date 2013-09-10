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

class Rechnung
  constructor: (@rechnungsnummer, @adresse, @datum, @einheiten, inklusive, @_rev) ->
    @id              = @rechnungsnummer or uuid()
    @inklusive       = if inklusive is undefined then true else !!inklusive

  add: (einheit) ->
    @einheiten.push einheit

  summe: ->
    @einheiten.reduce (sum, einheit) ->
      sum + einheit.summe()
    , 0

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

Rechnung.createFromCouch = (fn) -> (err, body) ->
  return fn err, body if err
  fn err, new Rechnung body.rechnungsnummer, body.adresse, body.datumstr, body.einheiten, body.inklusive, body._rev

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

create = (db) -> (rechnung, fn) ->
  db.insert rechnung, rechnung.id, (err, body) ->
    return fn err, body if err
    rechnung._rev = body.rev
    rechnung.id = body.id
    fn err, rechnung


read = (db) -> (rechnungsnummer, fn) ->
  if rechnungsnummer instanceof Rechnung
    rechnungsnummer = rechnungsnummer.rechnungsnummer

  db.get rechnungsnummer, Rechnung.createFromCouch fn


update = (db) -> (rechnung, fn) ->
  (create db) rechnung, Rechnung.createFromCouch fn

rechnungCouch =
  Rechnung    : Rechnung
  Einheit     : Einheit
  connect     : (db) ->
    onlyUnSend  : (fn) ->
    onlyUnpaid  : (fn) ->
    onlyPaid    : (fn) ->
    list        : (params, fn) ->
    create      : create db
    read        : read db
    update      : update db

module.exports = rechnungCouch

