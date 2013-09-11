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

deleteMockRechnung = (done) ->
  db.get mock.rechnung.rechnungsnummer, (err, body) ->
    return done() if err and err.error is 'not_found'
    should.not.exist err
    if body
      return db.destroy mock.rechnung.rechnungsnummer, body._rev, (err, body) ->
        should.not.exist err
        done()
    done()


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
      # ==== convenience views ====
      'onlyUnsend'
      'onlyUnpaid'
      'onlyPaid'
    ]
    rechnungCouch.Rechnung.should.have.keys = [
      'states'
    ]

  it "should have a model-factory", ->
    rechnungCouch.Rechnung.should.be.a 'function'
    rechnung = new rechnungCouch.Rechnung 'tmp-01'
    rechnung.should.be.a 'object'
    rechnung.should.have.property 'id'
    rechnung.id.should.be.a 'string'
    rechnung.state.should.be.a 'string'
    rechnung.state.should.be.equal 'created'
    rechnung.should.have.property 'rechnungsnummer'
    rechnung.should.have.property 'adresse'
    rechnung.should.have.property 'einheiten'
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
      it "should have no mock-rechnung", deleteMockRechnung

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

      describe "step 0", ->
        it "should have no mock-rechnung", deleteMockRechnung

      describe "step 1 - create rechnung", ->
        it "should create a rechnung", (done) ->
          @connection.create @rechnung, (err, rechnung) =>
            @tmp = rechnung
            should.not.exist err
            @tmp.should.be.instanceOf rechnungCouch.Rechnung
            done()

        it "should save the rechnung to the couch", (done) ->
          db.get @tmp.rechnungsnummer, (err, body) =>
            should.not.exist err
            body.id.should.be.equal @tmp.rechnungsnummer
            body.state.should.be.equal rechnungCouch.Rechnung.states.created
            @tmp = undefined
            done()

        it "should have cleaned the scope", ->
          (@tmp is undefined).should.be.true

      describe "step 1a - check", ->
        it "should show the rechnung in list-view", (done) ->
          @connection.list (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 1
            rechnung = rechnungen[0]
            rechnung.should.be.instanceOf rechnungCouch.Rechnung
            rechnung.rechnungsnummer.should.be.equal mock.rechnung.rechnungsnummer
            done()

        it "should have cleaned the scope", ->
          (@tmp is undefined).should.be.true

      describe "step 2 - send rechnung", ->
        it "should find the rechnung in unsend view", (done) ->
          @connection.onlyUnsend (err, rechnungen) =>
            should.not.exist err
            rechnungen.should.have.length 1
            @tmp = rechnungen[0]
            done()

        it "should not find the rechnung in unpaid view", (done) ->
          @connection.onlyUnpaid (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should not find the rechnung in paid view", (done) ->
          @connection.onlyPaid (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should send the rechnung", (done) -> @tmp.send db, done

        it "should have saved the rechnungs state to send", (done) ->
          db.get @tmp.rechnungsnummer, (err, body) =>
            should.not.exist err
            body.id.should.be.equal @tmp.rechnungsnummer
            body.state.should.be.equal rechnungCouch.Rechnung.states.send
            @tmp = undefined
            done()

        it "should have cleaned the scope", ->
          (@tmp is undefined).should.be.true

      describe "step 3 - pay rechnung", ->
        it "should not find the rechnung in unsend view", (done) ->
          @connection.onlyUnsend (err, rechnungen) =>
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should find the rechnung in unpaid view", (done) ->
          @connection.onlyUnpaid (err, rechnungen) =>
            should.not.exist err
            rechnungen.should.have.length 1
            @tmp = rechnungen[0]
            @tmp.should.be.instanceOf rechnungCouch.Rechnung
            done()

        it "should not find the rechnung in paid view", (done) ->
          @connection.onlyPaid (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should pay the rechnung", (done) -> @tmp.pay db, done

        it "should have saved the rechnungs state to paid", (done) ->
          db.get @tmp.rechnungsnummer, (err, body) =>
            should.not.exist err
            body.id.should.be.equal @tmp.rechnungsnummer
            body.state.should.be.equal rechnungCouch.Rechnung.states.paid
            @tmp = undefined
            done()

        it "should have cleaned the scope", ->
          (@tmp is undefined).should.be.true

      describe "step 4 - calculate and archive", ->
        it "should not find the rechnung in unsend view", (done) ->
          @connection.onlyUnsend (err, rechnungen) =>
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should not find the rechnung in unpaid view", (done) ->
          @connection.onlyUnpaid (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should find the rechnung in paid view", (done) ->
          @connection.onlyPaid (err, rechnungen) =>
            should.not.exist err
            rechnungen.should.have.length 1
            @tmp = rechnungen[0]
            @tmp.should.be.instanceOf rechnungCouch.Rechnung
            done()

        it "should sum and calculate the tax", ->
          @tmp.should.be.instanceOf rechnungCouch.Rechnung
          100.should.be.equal @tmp.summe()
          steuer = 100 / 119 * 100
          steuer.should.be.equal @tmp.summeSteuern()

        it "should archive the rechnung", (done) -> @tmp.archive db, done

        it "should have saved the rechnungs state to paid", (done) ->
          db.get @tmp.rechnungsnummer, (err, body) =>
            should.not.exist err
            body.id.should.be.equal @tmp.rechnungsnummer
            body.state.should.be.equal rechnungCouch.Rechnung.states.archived
            @tmp = undefined
            done()

        it "should have cleaned the scope", ->
          (@tmp is undefined).should.be.true

      describe "step 5 - check archive an delete", ->
        it "should find the rechnung in unsend view", (done) ->
          @connection.onlyUnsend (err, rechnungen) =>
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should not find the rechnung in unpaid view", (done) ->
          @connection.onlyUnpaid (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should not find the rechnung in paid view", (done) ->
          @connection.onlyPaid (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 0
            done()

        it "should find the rechnung in list-view", (done) ->
          @connection.list (err, rechnungen) ->
            should.not.exist err
            rechnungen.should.have.length 1
            done()

        it "should have cleaned the scope", ->
          (@tmp is undefined).should.be.true
