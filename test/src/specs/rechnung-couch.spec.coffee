rechnungCouch = source("rechnung-couch")

mock =
  rechnung:
    rechnungsnummer : '123-test'
    adresse         : ['123 Test Ave', '12345 Testington']
    datum           : '1st Fridgeday, ' + (new Date).getFullYear()
    inklusive       : true
  einheit_1:
    datum : (new Date).toString()
    text  : 'Einheit 1 - 2 Units @ 50€ = 100€'
    menge : 2
    preis : 50
  einheit_2:
    datum : (new Date).toString()
    text  : 'Einheit 2 - 1:30 @ 100€ / h = 150€'
    menge : '1:30'
    preis : 100

nano      = require('nano') 'http://localhost:5984'
database  = 'rechnungen'
db        = nano.use database


describe "basic tests", ->
  beforeEach ->
    @connection = rechnungCouch.connect db

  it "should have a method to get all rechnungen", ->
    rechnungCouch.should.have.keys [
      # ==== Models ====
      'Rechnung'
      'Einheit'
      # ==== connection ====
      'connect'
    ]
    @connection.should.have.keys = [
      # ==== CRUD ====
      'list'
      'create'
      'read'
      'update'
      # ==== convenience methods ====
      'onlyUnpaid'
      'onlyPaid'
      'onlySend'
    ]

  it "should have a model-factory", ->
    rechnungCouch.Rechnung.should.be.a 'function'
    rechnung = new rechnungCouch.Rechnung
    rechnung.should.be.a 'object'
    rechnung.should.have.property 'id'
    rechnung.id.should.be.a 'string'
    rechnung.should.not.have.property 'rechnungsnummer'
    rechnung.should.not.have.property 'adresse'
    rechnung.should.not.have.property 'einheiten'
    rechnung.should.have.property 'inklusive', true

  describe "checking models", ->

    beforeEach ->
      @einheiten = [
        new rechnungCouch.Einheit mock.einheit_1.datum, mock.einheit_1.text, mock.einheit_1.menge, mock.einheit_1.preis
      ]
      @rechnung = new rechnungCouch.Rechnung mock.rechnung.rechnungsnummer, mock.rechnung.adresse, mock.rechnung.datum, @einheiten, mock.rechnung.inklusive
      @einheit = new rechnungCouch.Einheit mock.einheit_2.datum, mock.einheit_2.text, mock.einheit_2.menge, mock.einheit_2.preis

    describe "Einheit", ->
      it "should calculate the sum for int(menge)", ->
        einheit = @rechnung.einheiten[0]
        einheit.should.be.instanceOf rechnungCouch.Einheit
        einheit.preis.should.be.equal 50
        einheit.menge.should.be.equal 2
        einheit.summe().should.be.equal 100

      it "should calculate the sum for date(menge)", ->
        einheit = @einheit
        einheit.should.be.instanceOf rechnungCouch.Einheit
        einheit.preis.should.be.equal 100
        einheit.menge.should.be.equal '1:30'
        einheit.summe().should.be.equal 150

    describe "Rechnung", ->

      it "basic `Rechnung` setup", ->
        @rechnung.should.be.instanceOf rechnungCouch.Rechnung
        @rechnung.id.should.be.equal mock.rechnung.rechnungsnummer
        @rechnung.rechnungsnummer.should.be.equal mock.rechnung.rechnungsnummer
        @rechnung.adresse.should.be.equal mock.rechnung.adresse
        @rechnung.inklusive.should.be.equal mock.rechnung.inklusive
        @rechnung.einheiten.should.have.length 1
        summe = @rechnung.summe()
        summe.should.be.a 'number'
        summe.should.be.equal 100

      it "should be able to add a `Einheit`", ->
        @rechnung.add @einheit
        @rechnung.einheiten.should.have.length 2
        summe = @rechnung.summe()
        summe.should.be.a 'number'
        summe.should.be.equal 250

    describe "CRUD", ->

      it "should create a document when saving `rechnung`", (done) ->
        @connection.create @rechnung, (err, rechnung) =>
          @Rechnung = rechnung
          should.not.exist err
          @Rechnung.should.be.instanceOf rechnungCouch.Rechnung
          done()

      it "should return the rechnung during read", (done) ->
        @connection.read @Rechnung.rechnungsnummer, (err, rechnung) =>
          @Rechnung.equal(rechnung).should.be.true
          done()

      it "should update the modified rechnung", (done) ->
        @Rechnung.add @einheit
        @connection.update @Rechnung, (err, rechnung) =>
          should.not.exist err
          @Rechnung.equal(rechnung).should.be.true
          done()

      it "should still return the rechnung during read", (done) ->
        @connection.read @Rechnung, (err, rechnung) =>
          @Rechnung.equal(rechnung).should.be.true
          done()

      it "should now delete the mocked document", (done) ->
        db.destroy mock.rechnung.rechnungsnummer, @Rechnung._rev, (err, body) ->
          should.not.exist err
          delete @Rechnung
          done()

    describe "Workflow", ->

      describe "step 1", ->
        it "should create a rechnung", ->
        it "should save the rechnung to the couch", ->

      describe "step 2", ->
        it "should read a unsend rechnung from the couch", ->
        it "should send the rechnung", ->
        it "should have saved the rechnungs state to send", ->

      describe "step 3", ->
        it "should read a send rechnung from the couch", ->
        it "should pay the rechnung", ->
        it "should have saved the rechnungs state to paid", ->

      describe "step 4", ->
        it "should read all paid rechnung from the couch", ->
        it "should sum and calculate the tax", ->

      it "should have done all this:", ->
        false.should.be.true