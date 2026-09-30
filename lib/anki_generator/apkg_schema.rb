# frozen_string_literal: true

require 'json'

module AnkiGenerator
  # Static Anki 2.1 collection definitions: the SQLite schema and the default
  # conf/deck/model JSON blobs that populate the col table. Extracted from
  # ApkgWriter so the writer deals only in rows and the archive.
  module ApkgSchema
    MODEL_ID = 1_609_739_310_911
    MODEL_NAME = 'AnkiGenerator'
    DECK_ID = 1
    SCHEMA_VERSION = 11

    CARD_CSS = <<~CSS
      .card {
        font-family: arial;
        font-size: 20px;
        text-align: center;
        color: black;
        background-color: white;
      }
    CSS

    SQL = <<~SQL
      CREATE TABLE col (
        id integer primary key,
        crt integer not null,
        mod integer not null,
        scm integer not null,
        ver integer not null,
        dty integer not null,
        usn integer not null,
        ls integer not null,
        conf text not null,
        models text not null,
        decks text not null,
        dconf text not null,
        tags text not null
      );
      CREATE TABLE notes (
        id integer primary key,
        guid text not null,
        mid integer not null,
        mod integer not null,
        usn integer not null,
        tags text not null,
        flds text not null,
        sfld integer not null,
        csum integer not null,
        flags integer not null,
        data text not null
      );
      CREATE TABLE cards (
        id integer primary key,
        nid integer not null,
        did integer not null,
        ord integer not null,
        mod integer not null,
        usn integer not null,
        type integer not null,
        queue integer not null,
        due integer not null,
        ivl integer not null,
        factor integer not null,
        reps integer not null,
        lapses integer not null,
        left integer not null,
        odue integer not null,
        odid integer not null,
        flags integer not null,
        data text not null
      );
      CREATE INDEX ix_cards_nid ON cards (nid);
      CREATE INDEX ix_notes_csum ON notes (csum);
    SQL

    module_function

    def conf_json
      JSON.generate(
        'nextPos' => 1,
        'estTimes' => true,
        'activeDecks' => [DECK_ID],
        'sortType' => 'noteFld',
        'timeLim' => 0,
        'sortBackwards' => false,
        'addToCur' => true,
        'curDeck' => DECK_ID,
        'newBury' => true,
        'newSpread' => 0,
        'dueDisplay' => 0,
        'collapseTime' => 1200,
        'curModel' => MODEL_ID.to_s
      )
    end

    def decks_json(deck_name:, now_seconds:)
      JSON.generate(
        DECK_ID.to_s => {
          'id' => DECK_ID,
          'mod' => now_seconds,
          'name' => deck_name,
          'usn' => -1,
          'lnewToday' => [0, 0],
          'lrnToday' => [0, 0],
          'revToday' => [0, 0],
          'timeToday' => [0, 0],
          'newToday' => [0, 0],
          'conf' => 1,
          'collapsed' => false,
          'dyn' => 0,
          'extendNew' => 0,
          'extendRev' => 0,
          'browserCollapsed' => true,
          'desc' => ''
        }
      )
    end

    def dconf_json
      JSON.generate(
        '1' => {
          'id' => 1,
          'mod' => 0,
          'name' => 'Default',
          'usn' => 0,
          'maxTaken' => 60,
          'timer' => 0,
          'autoplay' => true,
          'replayq' => true,
          'dyn' => false,
          'newMix' => 0,
          'newPer' => 0,
          'resched' => true,
          'new' => {
            'delays' => [1, 10],
            'ints' => [1, 4, 7],
            'initialFactor' => 2500,
            'separate' => true,
            'order' => 1,
            'perDay' => 20,
            'bury' => false
          },
          'lapse' => {
            'delays' => [10],
            'mult' => 0,
            'minInt' => 1,
            'leechFails' => 8,
            'leechAction' => 0
          },
          'rev' => {
            'perDay' => 200,
            'ease4' => 1.3,
            'fuzz' => 0.05,
            'minSpace' => 1,
            'ivlFct' => 1,
            'maxIvl' => 36_500
          }
        }
      )
    end

    def models_json(now_seconds:)
      JSON.generate(
        MODEL_ID.to_s => {
          'id' => MODEL_ID,
          'name' => MODEL_NAME,
          'mod' => now_seconds,
          'usn' => -1,
          'sortf' => 0,
          'type' => 0,
          'css' => CARD_CSS,
          'tags' => [],
          'flds' => [field('Front', 0), field('Back', 1)],
          'tmpls' => [template],
          'latexPre' => latex_pre,
          'latexPost' => '\\end{document}',
          'req' => [[0, 'any', [0]]]
        }
      )
    end

    def field(name, ord)
      {
        'name' => name,
        'ord' => ord,
        'sticky' => false,
        'rtl' => false,
        'font' => 'Arial',
        'size' => 20,
        'media' => []
      }
    end

    def template
      {
        'name' => 'Card 1',
        'ord' => 0,
        'qfmt' => '{{Front}}',
        'afmt' => "{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}",
        'did' => nil,
        'bqfmt' => '',
        'bafmt' => ''
      }
    end

    def latex_pre
      <<~LATEX
        \\documentclass[12pt]{article}
        \\special{papersize=3in,5in}
        \\usepackage[utf8]{inputenc}
        \\usepackage{amssymb,amsmath}
        \\pagestyle{empty}
        \\setlength{\\parindent}{0in}
        \\begin{document}
      LATEX
    end
  end
end
