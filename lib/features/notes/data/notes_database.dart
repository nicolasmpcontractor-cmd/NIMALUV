import 'dart:convert';

import 'package:nimahub_app/features/notes/models/note_models.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class NotesDatabase {
  NotesDatabase._();

  static final NotesDatabase instance = NotesDatabase._();

  static Database? _database;

  Future<Database> get database async {
    final currentDatabase = _database;

    if (currentDatabase != null) {
      return currentDatabase;
    }

    final openedDatabase = await _openDatabase();
    _database = openedDatabase;

    return openedDatabase;
  }

  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();

    final databasePath = join(databaseDirectory, 'nimahub_notes.db');

    return openDatabase(
      databasePath,
      version: 16,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE note_pages (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          page_kind TEXT NOT NULL DEFAULT 'note',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          emoji TEXT NOT NULL DEFAULT '',
          board_x REAL,
          board_y REAL,
          parent_folder_id TEXT,
          folder_order INTEGER NOT NULL DEFAULT 0
          )
          ''');

        await database.execute('''
  CREATE INDEX index_note_pages_parent_order
  ON note_pages(
    parent_folder_id,
    folder_order,
    updated_at
  )
  ''');

        await database.execute('''
  CREATE TABLE note_mind_map_positions (
    page_id TEXT NOT NULL,
    scope_id TEXT NOT NULL,
    position_x REAL NOT NULL,
    position_y REAL NOT NULL,
    PRIMARY KEY (page_id, scope_id),
    FOREIGN KEY (page_id)
      REFERENCES note_pages(id)
      ON DELETE CASCADE
  )
  ''');

        await database.execute('''
  CREATE INDEX index_note_mind_map_positions_scope
  ON note_mind_map_positions(scope_id)
  ''');

        await database.execute('''
          CREATE TABLE note_blocks (
            id TEXT PRIMARY KEY,
            note_id TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT NOT NULL,
            image_path TEXT,
            is_checked INTEGER NOT NULL DEFAULT 0,
            block_style TEXT NOT NULL DEFAULT 'normal',
            color_value INTEGER,
            font_family TEXT NOT NULL DEFAULT 'Inter',
            font_size REAL,
            text_color_value INTEGER,
            text_alignment TEXT NOT NULL DEFAULT 'left',
            list_marker_style TEXT NOT NULL DEFAULT 'automatic',
            checklist_states_json TEXT NOT NULL DEFAULT '[]',
            group_id TEXT,
            group_title TEXT NOT NULL DEFAULT '',
            group_collapsed INTEGER NOT NULL DEFAULT 0,
            position INTEGER NOT NULL,
            FOREIGN KEY (note_id)
              REFERENCES note_pages(id)
              ON DELETE CASCADE
          )
          ''');

        await database.execute('''
          CREATE INDEX index_note_blocks_note_id
          ON note_blocks(note_id)
          ''');

        await database.execute('''
          CREATE TABLE tracker_data (
            page_id TEXT PRIMARY KEY,
            description TEXT NOT NULL DEFAULT '',
            frequency TEXT NOT NULL DEFAULT 'daily',
            metric_type TEXT NOT NULL DEFAULT 'completion',
            target_value REAL NOT NULL DEFAULT 1,
            unit TEXT NOT NULL DEFAULT 'vez',
            status TEXT NOT NULL DEFAULT 'active',
            start_date INTEGER NOT NULL,
            reminder_enabled INTEGER NOT NULL DEFAULT 0,
            reminder_hour INTEGER NOT NULL DEFAULT 8,
            reminder_minute INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (page_id)
              REFERENCES note_pages(id)
              ON DELETE CASCADE
          )
          ''');

        await database.execute('''
          CREATE TABLE tracker_entries (
          id TEXT PRIMARY KEY,
          page_id TEXT NOT NULL,
          recorded_at INTEGER NOT NULL,
          value REAL NOT NULL DEFAULT 1,
          note TEXT NOT NULL DEFAULT '',
          image_path TEXT,
          source_module TEXT,
          external_id TEXT,
          FOREIGN KEY (page_id)
              REFERENCES note_pages(id)
              ON DELETE CASCADE
          )
          ''');

        await database.execute('''
          CREATE INDEX index_tracker_entries_page_date
          ON tracker_entries(page_id, recorded_at)
          ''');

        await database.execute('''
CREATE UNIQUE INDEX index_tracker_entries_external_reference
  ON tracker_entries(
    page_id,
    source_module,
    external_id
  )
  WHERE source_module IS NOT NULL
    AND source_module <> ''
    AND external_id IS NOT NULL
    AND external_id <> ''
  ''');

        await database.execute('''
  CREATE TABLE tracker_pauses (
    id TEXT PRIMARY KEY,
    page_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    FOREIGN KEY (page_id)
      REFERENCES note_pages(id)
      ON DELETE CASCADE
  )
  ''');

        await database.execute('''
  CREATE INDEX index_tracker_pauses_page_date
  ON tracker_pauses(page_id, started_at)
  ''');

        await database.execute('''
  CREATE TABLE tracker_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    tracker_title TEXT NOT NULL DEFAULT '',
    tracker_description TEXT NOT NULL DEFAULT '',
    frequency TEXT NOT NULL DEFAULT 'daily',
    metric_type TEXT NOT NULL DEFAULT 'completion',
    target_value REAL NOT NULL DEFAULT 1,
    unit TEXT NOT NULL DEFAULT 'vez',
    reminder_enabled INTEGER NOT NULL DEFAULT 0,
    reminder_hour INTEGER NOT NULL DEFAULT 8,
    reminder_minute INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
  ''');
      },
      onUpgrade: (database, oldVersion, _) async {
        final hasImagePath = await _columnExists(
          database,
          tableName: 'note_blocks',
          columnName: 'image_path',
        );

        if (!hasImagePath) {
          await database.execute('''
            ALTER TABLE note_blocks
            ADD COLUMN image_path TEXT
            ''');
        }

        final hasPageKind = await _columnExists(
          database,
          tableName: 'note_pages',
          columnName: 'page_kind',
        );

        if (!hasPageKind) {
          await database.execute('''
            ALTER TABLE note_pages
            ADD COLUMN page_kind TEXT NOT NULL DEFAULT 'note'
            ''');
        }

        final hasEmoji = await _columnExists(
          database,
          tableName: 'note_pages',
          columnName: 'emoji',
        );

        if (!hasEmoji) {
          await database.execute('''
    ALTER TABLE note_pages
    ADD COLUMN emoji TEXT NOT NULL DEFAULT ''
    ''');
        }

        if (oldVersion < 4) {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS tracker_data (
              page_id TEXT PRIMARY KEY,
              description TEXT NOT NULL DEFAULT '',
              frequency TEXT NOT NULL DEFAULT 'daily',
              metric_type TEXT NOT NULL DEFAULT 'completion',
              target_value REAL NOT NULL DEFAULT 1,
              unit TEXT NOT NULL DEFAULT 'vez',
              status TEXT NOT NULL DEFAULT 'active',
              start_date INTEGER NOT NULL,
              reminder_enabled INTEGER NOT NULL DEFAULT 0,
              reminder_hour INTEGER NOT NULL DEFAULT 8,
              reminder_minute INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (page_id)
                REFERENCES note_pages(id)
                ON DELETE CASCADE
            )
            ''');

          await database.execute('''
            CREATE TABLE IF NOT EXISTS tracker_entries (
              id TEXT PRIMARY KEY,
              page_id TEXT NOT NULL,
              recorded_at INTEGER NOT NULL,
              value REAL NOT NULL DEFAULT 1,
              note TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (page_id)
                REFERENCES note_pages(id)
                ON DELETE CASCADE
            )
            ''');

          await database.execute('''
            CREATE INDEX IF NOT EXISTS index_tracker_entries_page_date
            ON tracker_entries(page_id, recorded_at)
            ''');
        }
        if (oldVersion < 5) {
          await database.execute('''
CREATE TABLE IF NOT EXISTS tracker_pauses (
      id TEXT PRIMARY KEY,
      page_id TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      FOREIGN KEY (page_id)
        REFERENCES note_pages(id)
        ON DELETE CASCADE
    )
    ''');

          await database.execute('''
    CREATE INDEX IF NOT EXISTS index_tracker_pauses_page_date
    ON tracker_pauses(page_id, started_at)
    ''');
        }
        if (oldVersion < 6) {
          await database.execute('''
    CREATE TABLE IF NOT EXISTS tracker_templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      tracker_title TEXT NOT NULL DEFAULT '',
      tracker_description TEXT NOT NULL DEFAULT '',
      frequency TEXT NOT NULL DEFAULT 'daily',
      metric_type TEXT NOT NULL DEFAULT 'completion',
      target_value REAL NOT NULL DEFAULT 1,
      unit TEXT NOT NULL DEFAULT 'vez',
      reminder_enabled INTEGER NOT NULL DEFAULT 0,
      reminder_hour INTEGER NOT NULL DEFAULT 8,
      reminder_minute INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''');
        }
        if (oldVersion < 7) {
          final hasTrackerEntryImagePath = await _columnExists(
            database,
            tableName: 'tracker_entries',
            columnName: 'image_path',
          );

          if (!hasTrackerEntryImagePath) {
            await database.execute('''
      ALTER TABLE tracker_entries
      ADD COLUMN image_path TEXT
      ''');
          }
        }

        if (oldVersion < 8) {
          final hasSourceModule = await _columnExists(
            database,
            tableName: 'tracker_entries',
            columnName: 'source_module',
          );

          if (!hasSourceModule) {
            await database.execute('''
      ALTER TABLE tracker_entries
      ADD COLUMN source_module TEXT
      ''');
          }

          final hasExternalId = await _columnExists(
            database,
            tableName: 'tracker_entries',
            columnName: 'external_id',
          );

          if (!hasExternalId) {
            await database.execute('''
      ALTER TABLE tracker_entries
      ADD COLUMN external_id TEXT
      ''');
          }

          await database.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS
    index_tracker_entries_external_reference
    ON tracker_entries(
      page_id,
      source_module,
      external_id
    )
    WHERE source_module IS NOT NULL
      AND source_module <> ''
      AND external_id IS NOT NULL
      AND external_id <> ''
    ''');
        }

        if (oldVersion < 9) {
          final hasBoardX = await _columnExists(
            database,
            tableName: 'note_pages',
            columnName: 'board_x',
          );

          if (!hasBoardX) {
            await database.execute('''
      ALTER TABLE note_pages
      ADD COLUMN board_x REAL
      ''');
          }

          final hasBoardY = await _columnExists(
            database,
            tableName: 'note_pages',
            columnName: 'board_y',
          );

          if (!hasBoardY) {
            await database.execute('''
      ALTER TABLE note_pages
      ADD COLUMN board_y REAL
      ''');
          }
        }

        if (oldVersion < 10) {
          final hasParentFolderId = await _columnExists(
            database,
            tableName: 'note_pages',
            columnName: 'parent_folder_id',
          );

          if (!hasParentFolderId) {
            await database.execute('''
      ALTER TABLE note_pages
      ADD COLUMN parent_folder_id TEXT
      ''');
          }

          final hasFolderOrder = await _columnExists(
            database,
            tableName: 'note_pages',
            columnName: 'folder_order',
          );

          if (!hasFolderOrder) {
            await database.execute('''
      ALTER TABLE note_pages
      ADD COLUMN folder_order INTEGER NOT NULL DEFAULT 0
      ''');
          }

          await database.execute('''
    CREATE INDEX IF NOT EXISTS
    index_note_pages_parent_order
    ON note_pages(
      parent_folder_id,
      folder_order,
      updated_at
    )
    ''');
        }

        if (oldVersion < 11) {
          await database.execute('''
    CREATE TABLE IF NOT EXISTS note_mind_map_positions (
      page_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      position_x REAL NOT NULL,
      position_y REAL NOT NULL,
      PRIMARY KEY (page_id, scope_id),
      FOREIGN KEY (page_id)
        REFERENCES note_pages(id)
        ON DELETE CASCADE
    )
    ''');

          await database.execute('''
    CREATE INDEX IF NOT EXISTS
    index_note_mind_map_positions_scope
    ON note_mind_map_positions(scope_id)
    ''');
        }

        if (oldVersion < 12) {
          final hasBlockStyle = await _columnExists(
            database,
            tableName: 'note_blocks',
            columnName: 'block_style',
          );

          if (!hasBlockStyle) {
            await database.execute('''
      ALTER TABLE note_blocks
      ADD COLUMN block_style TEXT NOT NULL DEFAULT 'normal'
      ''');
          }

          final hasColorValue = await _columnExists(
            database,
            tableName: 'note_blocks',
            columnName: 'color_value',
          );

          if (!hasColorValue) {
            await database.execute('''
      ALTER TABLE note_blocks
      ADD COLUMN color_value INTEGER
      ''');
          }

          await database.execute('''
      UPDATE note_blocks
      SET
        block_style = CASE type
          WHEN 'heading1' THEN 'heading1'
          WHEN 'heading2' THEN 'heading2'
          WHEN 'quote' THEN 'quote'
          WHEN 'callout' THEN 'callout'
          ELSE block_style
        END,
        type = CASE
          WHEN type IN (
            'heading1',
            'heading2',
            'quote',
            'callout'
          ) THEN 'paragraph'
          ELSE type
        END
      ''');
        }

        if (oldVersion < 13) {
          final formattingColumns = <String, String>{
            'font_family': "TEXT NOT NULL DEFAULT 'Inter'",
            'font_size': 'REAL',
            'text_color_value': 'INTEGER',
            'text_alignment': "TEXT NOT NULL DEFAULT 'left'",
            'list_marker_style': "TEXT NOT NULL DEFAULT 'automatic'",
          };

          for (final entry in formattingColumns.entries) {
            final exists = await _columnExists(
              database,
              tableName: 'note_blocks',
              columnName: entry.key,
            );

            if (!exists) {
              await database.execute('''
                ALTER TABLE note_blocks
                ADD COLUMN ${entry.key} ${entry.value}
                ''');
            }
          }
        }

        if (oldVersion < 14) {
          final hasChecklistStates = await _columnExists(
            database,
            tableName: 'note_blocks',
            columnName: 'checklist_states_json',
          );

          if (!hasChecklistStates) {
            await database.execute('''
              ALTER TABLE note_blocks
              ADD COLUMN checklist_states_json TEXT NOT NULL DEFAULT '[]'
              ''');
          }
        }

        if (oldVersion < 15) {
          final groupColumns = <String, String>{
            'group_id': 'TEXT',
            'group_title': "TEXT NOT NULL DEFAULT ''",
            'group_collapsed': 'INTEGER NOT NULL DEFAULT 0',
          };

          for (final entry in groupColumns.entries) {
            final exists = await _columnExists(
              database,
              tableName: 'note_blocks',
              columnName: entry.key,
            );

            if (!exists) {
              await database.execute('''
        ALTER TABLE note_blocks
        ADD COLUMN ${entry.key} ${entry.value}
        ''');
            }
          }
        }
      },
    );
  }

  Future<bool> _columnExists(
    Database database, {
    required String tableName,
    required String columnName,
  }) async {
    final columns = await database.rawQuery('PRAGMA table_info($tableName)');

    return columns.any((column) {
      return column['name'] == columnName;
    });
  }

  List<bool> _decodeChecklistStates(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const <bool>[];
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is! List) {
        return const <bool>[];
      }

      return decoded.map((value) => value == true || value == 1).toList();
    } catch (_) {
      return const <bool>[];
    }
  }

  Future<List<NotePage>> readNotes() async {
    final db = await database;

    final pageRows = await db.query(
      'note_pages',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    final notes = <NotePage>[];

    for (final pageRow in pageRows) {
      final noteId = pageRow['id'] as String;

      final blockRows = await db.query(
        'note_blocks',
        where: 'note_id = ?',
        whereArgs: [noteId],
        orderBy: 'position ASC',
      );

      final blocks = blockRows.map((blockRow) {
        return NoteBlock(
          id: blockRow['id'] as String,
          type: NoteBlockType.values.byName(blockRow['type'] as String),
          text: blockRow['text'] as String,
          isChecked: (blockRow['is_checked'] as int) == 1,
          imagePath: blockRow['image_path'] as String?,
          style: NoteBlockStyle.values.firstWhere((style) {
            return style.name ==
                (blockRow['block_style'] as String? ?? 'normal');
          }, orElse: () => NoteBlockStyle.normal),
          colorValue: (blockRow['color_value'] as num?)?.toInt(),
          fontFamily: blockRow['font_family'] as String? ?? 'Inter',
          fontSize: (blockRow['font_size'] as num?)?.toDouble(),
          textColorValue: (blockRow['text_color_value'] as num?)?.toInt(),
          textAlignment: NoteTextAlignment.values.firstWhere(
            (alignment) =>
                alignment.name ==
                (blockRow['text_alignment'] as String? ?? 'left'),
            orElse: () => NoteTextAlignment.left,
          ),
          listMarkerStyle: NoteListMarkerStyle.values.firstWhere(
            (marker) =>
                marker.name ==
                (blockRow['list_marker_style'] as String? ?? 'automatic'),
            orElse: () => NoteListMarkerStyle.automatic,
          ),
          checklistStates: _decodeChecklistStates(
            blockRow['checklist_states_json'] as String?,
          ),
          groupId: blockRow['group_id'] as String?,
          groupTitle: blockRow['group_title'] as String? ?? '',
          groupCollapsed:
              ((blockRow['group_collapsed'] as num?)?.toInt() ?? 0) == 1,
        );
      }).toList();

      notes.add(
        NotePage(
          id: noteId,
          title: pageRow['title'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            pageRow['created_at'] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            pageRow['updated_at'] as int,
          ),
          blocks: blocks,
          kind: NotePageKind.values.firstWhere((kind) {
            return kind.name == (pageRow['page_kind'] as String? ?? 'note');
          }, orElse: () => NotePageKind.note),
          isPinned: (pageRow['is_pinned'] as int) == 1,
          emoji: pageRow['emoji'] as String? ?? '',
          boardX: (pageRow['board_x'] as num?)?.toDouble(),
          boardY: (pageRow['board_y'] as num?)?.toDouble(),
          parentFolderId: pageRow['parent_folder_id'] as String?,
          folderOrder: (pageRow['folder_order'] as num? ?? 0).toInt(),
        ),
      );
    }

    return notes;
  }

  Future<List<NoteMindMapPosition>> readMindMapPositions() async {
    final db = await database;

    final rows = await db.query(
      'note_mind_map_positions',
      orderBy: 'scope_id ASC, page_id ASC',
    );

    return rows.map((row) {
      return NoteMindMapPosition(
        pageId: row['page_id'] as String,
        scopeId: row['scope_id'] as String,
        x: (row['position_x'] as num).toDouble(),
        y: (row['position_y'] as num).toDouble(),
      );
    }).toList();
  }

  Future<TrackerData?> readTrackerData(String pageId) async {
    final db = await database;

    final rows = await db.query(
      'tracker_data',
      where: 'page_id = ?',
      whereArgs: [pageId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return TrackerData(
      pageId: row['page_id'] as String,
      description: row['description'] as String? ?? '',
      frequency: TrackerFrequency.values.firstWhere((frequency) {
        return frequency.name == (row['frequency'] as String? ?? 'daily');
      }, orElse: () => TrackerFrequency.daily),
      metricType: TrackerMetricType.values.firstWhere((metricType) {
        return metricType.name ==
            (row['metric_type'] as String? ?? 'completion');
      }, orElse: () => TrackerMetricType.completion),
      targetValue: (row['target_value'] as num? ?? 1).toDouble(),
      unit: row['unit'] as String? ?? 'vez',
      status: TrackerStatus.values.firstWhere((status) {
        return status.name == (row['status'] as String? ?? 'active');
      }, orElse: () => TrackerStatus.active),
      startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date'] as int),
      reminderEnabled: (row['reminder_enabled'] as int? ?? 0) == 1,
      reminderHour: row['reminder_hour'] as int? ?? 8,
      reminderMinute: row['reminder_minute'] as int? ?? 0,
    );
  }

  Future<List<TrackerEntry>> readTrackerEntries(String pageId) async {
    final db = await database;

    final rows = await db.query(
      'tracker_entries',
      where: 'page_id = ?',
      whereArgs: [pageId],
      orderBy: 'recorded_at DESC',
    );

    return rows.map((row) {
      return TrackerEntry(
        id: row['id'] as String,
        pageId: row['page_id'] as String,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
          row['recorded_at'] as int,
        ),
        value: (row['value'] as num? ?? 0).toDouble(),
        note: row['note'] as String? ?? '',
        imagePath: row['image_path'] as String?,
        sourceModule: row['source_module'] as String?,
        externalId: row['external_id'] as String?,
      );
    }).toList();
  }

  Future<List<TrackerPause>> readTrackerPauses(String pageId) async {
    final db = await database;

    final rows = await db.query(
      'tracker_pauses',
      where: 'page_id = ?',
      whereArgs: [pageId],
      orderBy: 'started_at ASC',
    );

    return rows.map((row) {
      final endedAtValue = row['ended_at'] as int?;

      return TrackerPause(
        id: row['id'] as String,
        pageId: row['page_id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          row['started_at'] as int,
        ),
        endedAt: endedAtValue == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(endedAtValue),
      );
    }).toList();
  }

  Future<List<TrackerTemplate>> readTrackerTemplates() async {
    final db = await database;

    final rows = await db.query(
      'tracker_templates',
      orderBy: 'updated_at DESC',
    );

    return rows.map((row) {
      return TrackerTemplate(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        description: row['description'] as String? ?? '',
        trackerTitle: row['tracker_title'] as String? ?? '',
        trackerDescription: row['tracker_description'] as String? ?? '',
        frequency: TrackerFrequency.values.firstWhere((frequency) {
          return frequency.name == (row['frequency'] as String? ?? 'daily');
        }, orElse: () => TrackerFrequency.daily),
        metricType: TrackerMetricType.values.firstWhere((metricType) {
          return metricType.name ==
              (row['metric_type'] as String? ?? 'completion');
        }, orElse: () => TrackerMetricType.completion),
        targetValue: (row['target_value'] as num? ?? 1).toDouble(),
        unit: row['unit'] as String? ?? 'vez',
        reminderEnabled: (row['reminder_enabled'] as int? ?? 0) == 1,
        reminderHour: row['reminder_hour'] as int? ?? 8,
        reminderMinute: row['reminder_minute'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int,
        ),
      );
    }).toList();
  }

  Future<void> insertNote(NotePage note) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.insert(
        'note_pages',
        _pageToMap(note),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _insertBlocks(transaction, note);
    });
  }

  Future<void> insertTrackerPage(NotePage page, TrackerData tracker) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.insert(
        'note_pages',
        _pageToMap(page),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _insertBlocks(transaction, page);

      await transaction.insert(
        'tracker_data',
        _trackerDataToMap(tracker),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> upsertTrackerData(TrackerData tracker) async {
    final db = await database;

    await db.insert(
      'tracker_data',
      _trackerDataToMap(tracker),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertTrackerEntry(TrackerEntry entry) async {
    final db = await database;

    final values = _trackerEntryToMap(entry);

    final updateValues = Map<String, Object?>.from(values)..remove('id');

    final updatedRows = await db.update(
      'tracker_entries',
      updateValues,
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    if (updatedRows != 0) {
      return;
    }

    await db.insert(
      'tracker_entries',
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> deleteTrackerEntry(String entryId) async {
    final db = await database;

    await db.delete('tracker_entries', where: 'id = ?', whereArgs: [entryId]);
  }

  Future<void> insertTrackerPause(TrackerPause pause) async {
    final db = await database;

    await db.insert('tracker_pauses', {
      'id': pause.id,
      'page_id': pause.pageId,
      'started_at': pause.startedAt.millisecondsSinceEpoch,
      'ended_at': pause.endedAt?.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> closeTrackerPause(String pauseId, DateTime endedAt) async {
    final db = await database;

    await db.update(
      'tracker_pauses',
      {'ended_at': endedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [pauseId],
    );
  }

  Future<void> upsertTrackerTemplate(TrackerTemplate template) async {
    final db = await database;

    await db.insert(
      'tracker_templates',
      _trackerTemplateToMap(template),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTrackerTemplate(String templateId) async {
    final db = await database;

    await db.delete(
      'tracker_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );
  }

  Future<void> updateNoteBoardPosition({
    required String noteId,
    required double x,
    required double y,
  }) async {
    final db = await database;

    await db.update(
      'note_pages',
      {'board_x': x, 'board_y': y},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<void> upsertMindMapPosition({
    required String pageId,
    required String scopeId,
    required double x,
    required double y,
  }) async {
    final db = await database;

    await db.insert('note_mind_map_positions', {
      'page_id': pageId,
      'scope_id': scopeId,
      'position_x': x,
      'position_y': y,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMindMapPositionsForScope(String scopeId) async {
    final db = await database;

    await db.delete(
      'note_mind_map_positions',
      where: 'scope_id = ?',
      whereArgs: [scopeId],
    );
  }

  Future<void> updateNoteOrders(List<String> orderedNoteIds) async {
    if (orderedNoteIds.isEmpty) {
      return;
    }

    final db = await database;

    await db.transaction((transaction) async {
      for (var index = 0; index < orderedNoteIds.length; index++) {
        await transaction.update(
          'note_pages',
          {'folder_order': index},
          where: 'id = ?',
          whereArgs: [orderedNoteIds[index]],
        );
      }
    });
  }

  Future<void> updateNoteFolder({
    required String noteId,
    required String? parentFolderId,
    required int folderOrder,
  }) async {
    final db = await database;

    await db.update(
      'note_pages',
      {
        'parent_folder_id': parentFolderId,
        'folder_order': folderOrder,
        'board_x': null,
        'board_y': null,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<void> deleteNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) {
      return;
    }

    final db = await database;

    await db.transaction((transaction) async {
      for (final noteId in noteIds) {
        await transaction.delete(
          'note_mind_map_positions',
          where: 'scope_id = ?',
          whereArgs: [noteId],
        );

        await transaction.delete(
          'note_pages',
          where: 'id = ?',
          whereArgs: [noteId],
        );
      }
    });
  }

  Future<void> moveFolderChildrenAndDeleteFolder({
    required String folderId,
    required List<NotePage> movedChildren,
  }) async {
    final db = await database;

    await db.transaction((transaction) async {
      for (final child in movedChildren) {
        await transaction.update(
          'note_pages',
          {
            'parent_folder_id': child.parentFolderId,
            'folder_order': child.folderOrder,
            'board_x': child.boardX,
            'board_y': child.boardY,
          },
          where: 'id = ?',
          whereArgs: [child.id],
        );
      }

      await transaction.delete(
        'note_mind_map_positions',
        where: 'scope_id = ?',
        whereArgs: [folderId],
      );

      await transaction.delete(
        'note_pages',
        where: 'id = ?',
        whereArgs: [folderId],
      );
    });
  }

  Future<void> updateNote(NotePage note) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.update(
        'note_pages',
        _pageToMap(note),
        where: 'id = ?',
        whereArgs: [note.id],
      );

      await transaction.delete(
        'note_blocks',
        where: 'note_id = ?',
        whereArgs: [note.id],
      );

      await _insertBlocks(transaction, note);
    });
  }

  Future<void> deleteNote(String noteId) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.delete(
        'note_mind_map_positions',
        where: 'scope_id = ?',
        whereArgs: [noteId],
      );

      await transaction.delete(
        'note_pages',
        where: 'id = ?',
        whereArgs: [noteId],
      );
    });
  }

  Map<String, Object?> _trackerTemplateToMap(TrackerTemplate template) {
    return {
      'id': template.id,
      'name': template.name,
      'description': template.description,
      'tracker_title': template.trackerTitle,
      'tracker_description': template.trackerDescription,
      'frequency': template.frequency.name,
      'metric_type': template.metricType.name,
      'target_value': template.targetValue,
      'unit': template.unit,
      'reminder_enabled': template.reminderEnabled ? 1 : 0,
      'reminder_hour': template.reminderHour,
      'reminder_minute': template.reminderMinute,
      'created_at': template.createdAt.millisecondsSinceEpoch,
      'updated_at': template.updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, Object?> _trackerDataToMap(TrackerData tracker) {
    return {
      'page_id': tracker.pageId,
      'description': tracker.description,
      'frequency': tracker.frequency.name,
      'metric_type': tracker.metricType.name,
      'target_value': tracker.targetValue,
      'unit': tracker.unit,
      'status': tracker.status.name,
      'start_date': tracker.startDate.millisecondsSinceEpoch,
      'reminder_enabled': tracker.reminderEnabled ? 1 : 0,
      'reminder_hour': tracker.reminderHour,
      'reminder_minute': tracker.reminderMinute,
    };
  }

  Map<String, Object?> _trackerEntryToMap(TrackerEntry entry) {
    return {
      'id': entry.id,
      'page_id': entry.pageId,
      'recorded_at': entry.recordedAt.millisecondsSinceEpoch,
      'value': entry.value,
      'note': entry.note,
      'image_path': entry.imagePath,
      'source_module': entry.sourceModule,
      'external_id': entry.externalId,
    };
  }

  Map<String, Object?> _pageToMap(NotePage note) {
    return {
      'id': note.id,
      'title': note.title,
      'page_kind': note.kind.name,
      'created_at': note.createdAt.millisecondsSinceEpoch,
      'updated_at': note.updatedAt.millisecondsSinceEpoch,
      'is_pinned': note.isPinned ? 1 : 0,
      'emoji': note.emoji,
      'board_x': note.boardX,
      'board_y': note.boardY,
      'parent_folder_id': note.parentFolderId,
      'folder_order': note.folderOrder,
    };
  }

  Future<void> _insertBlocks(DatabaseExecutor executor, NotePage note) async {
    for (var index = 0; index < note.blocks.length; index++) {
      final block = note.blocks[index];

      await executor.insert('note_blocks', {
        'id': block.id,
        'note_id': note.id,
        'type': block.type.name,
        'text': block.text,
        'image_path': block.imagePath,
        'is_checked': block.isChecked ? 1 : 0,
        'block_style': block.style.name,
        'color_value': block.colorValue,
        'font_family': block.fontFamily,
        'font_size': block.fontSize,
        'text_color_value': block.textColorValue,
        'text_alignment': block.textAlignment.name,
        'list_marker_style': block.listMarkerStyle.name,
        'checklist_states_json': jsonEncode(block.checklistStates),
        'group_id': block.groupId,
        'group_title': block.groupTitle,
        'group_collapsed': block.groupCollapsed ? 1 : 0,
        'position': index,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> close() async {
    final currentDatabase = _database;

    if (currentDatabase == null) {
      return;
    }

    await currentDatabase.close();
    _database = null;
  }
}
