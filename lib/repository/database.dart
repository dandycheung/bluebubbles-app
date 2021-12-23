import 'dart:async';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
//ignore: implementation_imports
import 'package:objectbox/src/transaction.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_io/io.dart';

import 'helpers/migration_map.dart';

enum Tables {
  chat,
  handle,
  message,
  attachment,
  chat_handle_join,
  chat_message_join,
  attachment_message_join,
  themes,
  theme_values,
  theme_value_join,
  fcm,
}

class DBUpgradeItem {
  int addedInVersion;
  Function(Database) upgrade;

  DBUpgradeItem({required this.addedInVersion, required this.upgrade});
}

class DBProvider {
  DBProvider._();

  static final DBProvider db = DBProvider._();

  static int currentVersion = 14;

  /// Contains list of functions to invoke when going from a previous to the current database verison
  /// The previous version is always [key - 1], for example for key 2, it will be the upgrade scheme from version 1 to version 2
  static final List<DBUpgradeItem> upgradeSchemes = [
    DBUpgradeItem(
        addedInVersion: 2,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN hasDdResults INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 3,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN balloonBundleId TEXT DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN isFiltered INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 4,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN dateDeleted INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN isPinned INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 5,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE attachment ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE message ADD COLUMN otherHandle INTEGER DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 6,
        upgrade: (Database db) {
          db.execute("ALTER TABLE attachment ADD COLUMN metadata TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 7,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN metadata TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 8,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN color TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 9,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN defaultPhone TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 10,
        upgrade: (Database db) {
          db.execute("ALTER TABLE chat ADD COLUMN customAvatarPath TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 11,
        upgrade: (Database db) {
          db.execute("ALTER TABLE chat ADD COLUMN pinIndex INTEGER DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 12,
        upgrade: (Database db) async {
          db.execute("ALTER TABLE chat ADD COLUMN muteType TEXT DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN muteArgs TEXT DEFAULT NULL;");
          await db.update("chat", {'muteType': 'mute'}, where: "isMuted = ?", whereArgs: [1]);
        }),
    DBUpgradeItem(
        addedInVersion: 13,
        upgrade: (Database db) {
          db.execute("ALTER TABLE themes ADD COLUMN gradientBg INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 14,
        upgrade: (Database db) async {
          db.execute("ALTER TABLE themes ADD COLUMN previousLightTheme INTEGER DEFAULT 0;");
          db.execute("ALTER TABLE themes ADD COLUMN previousDarkTheme INTEGER DEFAULT 0;");
          Settings s = await Settings.getSettingsOld(db);
          s.save();
          db.execute("DELETE FROM config");
        }),
  ];

  Future<Database> initDB({Future<void> Function()? initStore}) async {
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    }
    //ignore: unnecessary_cast, we need this as a workaround
    Directory documentsDirectory = (await getApplicationDocumentsDirectory()) as Directory;
    //ignore: unnecessary_cast, we need this as a workaround
    if (kIsDesktop) documentsDirectory = (await getApplicationSupportDirectory()) as Directory;
    String path = join(documentsDirectory.path, "chat.db");
    return await openDatabase(path, version: currentVersion, onUpgrade: _onUpgrade, onOpen: (Database db) async {
      Logger.info("Database Opened");
      await migrateToObjectBox(db, initStore);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run each upgrade scheme for every difference in version.
    // If the user is on version 1 and they need to upgrade to version 3,
    // then we will run every single scheme from 1 -> 2 and 2 -> 3

    for (DBUpgradeItem item in upgradeSchemes) {
      if (oldVersion < item.addedInVersion) {
        Logger.info("Upgrading DB from version $oldVersion to version $newVersion");

        try {
          await item.upgrade(db);
        } catch (ex) {
          Logger.error("Failed to perform DB upgrade: ${ex.toString()}");
        }
      }
    }
  }

  static Future<void> deleteDB() async {
    if (kIsWeb) return;
    attachmentBox.removeAll();
    chatBox.removeAll();
    fcmDataBox.removeAll();
    handleBox.removeAll();
    messageBox.removeAll();
    scheduledBox.removeAll();
    themeEntryBox.removeAll();
    themeObjectBox.removeAll();
  }

  Future<void> migrateToObjectBox(Database db, Future<void> Function()? initStore) async {
    if (initStore == null) return;

    // Start a timer so we can track how long it takes to extract the data from the old database
    Stopwatch s = Stopwatch();
    s.start();

    // Pull all the table data from the database and store them locally, in memory (temporarily)
    List<List<dynamic>> tableData = [];
    for (Tables tableName in Tables.values) {
      final table = await db.rawQuery("SELECT * FROM ${tableName.toString().split(".").last}");
      tableData.add(table);
    }
    s.stop();
    Logger.info("Pulled data in ${s.elapsedMilliseconds} ms");

    // Initialize the object box storage
    await initStore.call();

    // Remove any items currently residing in the object box database
    deleteDB();

    // The general premise of the migration is to transfer every single bit
    // of data from SQLite into ObjectBox. The most important thing to keep
    // track of are the IDs, since we have numerous queries that relate IDs
    // from one table to IDs from another table.
    //
    // As such, this code will create a "migration map", which contains some
    // unique identifying characteristic of the data item as the key, and
    // then another map containing the old (SQLite) ID and the new (ObjectBox)
    // ID as the value.
    //
    // This map is then used when saving the "join" tables, which would still
    // have the old (SQLite) IDs for each data item. Using the map, we can
    // update that old ID to the new ID and thus avoid creating an incorrect
    // link due to the ID mismatch.
    store.runInTransaction(TxMode.write, () {
      // Migrate all the main tables
      final chatMigrationMap = migrateChats(tableData[0]);
      final handleMigrationMap = migrateHandles(tableData[1]);
      final messageMigrationMap = migrateMessages(tableData[2], handleMigrationMap);
      final attachmentMigrationMap = migrateAttachments(tableData[3]);

      // Migrate all the join tables
      migrateChatHandleJoin(tableData[4], chatMigrationMap, handleMigrationMap);
      migrateChatMessageJoin(tableData[5], chatMigrationMap, messageMigrationMap);
      migrateAttachmentMessageJoin(tableData[6], attachmentMigrationMap, messageMigrationMap);

      // NOTE: I'm too lazy to migrate all these right now.
      // Luckily, none of these were causing issues for people
      Logger.info("Migrating theme objects...", tag: "OB Migration");
      final themeObjects = tableData[7].map((e) => ThemeObject.fromMap(e)).toList();
      final themeObjectIdsMigrationMap = <String, Map<String, int>>{};
      for (ThemeObject element in themeObjects) {
        themeObjectIdsMigrationMap[element.name!] = {
          "old": element.id!
        };
        element.id = null;
      }
      Logger.info("Created theme object ID migration map, length ${themeObjectIdsMigrationMap.length}", tag: "OB Migration");
      themeObjectBox.putMany(themeObjects);
      Logger.info("Inserted theme objects into ObjectBox", tag: "OB Migration");
      final newThemeObjects = themeObjectBox.getAll();
      Logger.info("Fetched ObjectBox theme objects, length ${newThemeObjects.length}", tag: "OB Migration");
      for (ThemeObject element in newThemeObjects) {
        themeObjectIdsMigrationMap[element.name]!['new'] = element.id!;
      }
      Logger.info("Added new IDs to theme object ID migration map", tag: "OB Migration");
      themeObjects.clear();
      newThemeObjects.clear();
      Logger.info("Migrating theme entries...", tag: "OB Migration");
      final themeEntries = tableData[8].map((e) => ThemeEntry.fromMap(e)).toList();
      final themeEntryIdsMigrationMap = <String, Map<String, int>>{};
      for (ThemeEntry element in themeEntries) {
        // we will always have a new and an old form of ID, so these should never error
        final newThemeId = themeObjectIdsMigrationMap.values.firstWhere((e) => e['old'] == element.themeId)['new'];
        element.themeId = newThemeId!;
        themeEntryIdsMigrationMap["${element.name}-${element.themeId!}"] = {
          "old": element.id!
        };
        element.id = null;
      }
      Logger.info("Created theme entry ID migration map, length ${themeEntryIdsMigrationMap.length}", tag: "OB Migration");
      themeEntryBox.putMany(themeEntries);
      Logger.info("Inserted theme entries into ObjectBox", tag: "OB Migration");
      final newThemeEntries = themeEntryBox.getAll();
      Logger.info("Fetched ObjectBox theme entries, length ${newThemeEntries.length}", tag: "OB Migration");
      for (ThemeEntry element in newThemeEntries) {
        themeEntryIdsMigrationMap["${element.name}-${element.themeId!}"]!['new'] = element.id!;
      }
      Logger.info("Added new IDs to theme entry ID", tag: "OB Migration");
      themeEntries.clear();
      newThemeEntries.clear();
      Logger.info("Migrating theme-value joins...", tag: "OB Migration");
      List<ThemeValueJoin> tvJoins = tableData[9].map((e) => ThemeValueJoin.fromMap(e)).toList();
      for (ThemeValueJoin tvj in tvJoins) {
        // we will always have a new and an old form of ID, so these should never error
        final newThemeId = themeObjectIdsMigrationMap.values.firstWhere((e) => e['old'] == tvj.themeId)['new'];
        final newThemeValueId = themeEntryIdsMigrationMap.values.firstWhere((e) => e['old'] == tvj.themeValueId)['new'];
        tvj.themeId = newThemeId!;
        tvj.themeValueId = newThemeValueId!;
      }
      Logger.info("Replaced old theme object & theme entry IDs with new ObjectBox IDs", tag: "OB Migration");
      final themeValues2 = themeEntryBox.getAll();
      for (int i = 0; i < themeValues2.length; i++) {
        // this migration must happen cleanly, we cannot ignore any null errors
        // the theme values must all associate with a theme object, otherwise
        // there will be errors when trying to load the theme
        final themeId = tvJoins.firstWhere((e) => e.themeValueId == themeValues2[i].id).themeId;
        final themeObject = themeObjectBox.get(themeId);
        themeValues2[i].themeObject.target = themeObject;
      }
      themeEntryBox.putMany(themeValues2);
      Logger.info("Inserted theme-value joins into ObjectBox", tag: "OB Migration");
      tvJoins.clear();
    });

    // Load the FCM config entries
    Logger.info("Migrating FCM data...", tag: "OB Migration");
    List<ConfigEntry> entries = [];
    for (Map<String, dynamic> setting in tableData[10]) {
      entries.add(ConfigEntry.fromMap(setting));
    }

    // Save the FCM config entries to ObjectBox
    final fcm = FCMData.fromConfigEntries(entries);
    Logger.info("Parsed FCM data from SQLite", tag: "OB Migration");
    fcm.save();
    Logger.info("Inserted FCM data into ObjectBox", tag: "OB Migration");

    // Set a flag to complete the migration
    prefs.setBool('objectbox-migration', true);
    Logger.info("Migration to ObjectBox complete!", tag: "OB Migration");
  }

  MigrationMap migrateChats(List<dynamic> tableChats) {
    // Convert list of table rows to a list of Chat objects
    Logger.info("Migrating ${tableChats.length} chats...", tag: "OB Migration");
    final chats = tableChats.map((e) => Chat.fromMap(e)).toList();
    final chatMigrationMap = MigrationMap();

    // Create a map using the GUID as the key and the value is a map containing the old and new IDs
    // We also want to reset the element's ID to null so when we insert, it doesn't use the old ID
    for (Chat element in chats) {
      chatMigrationMap.set(element.guid!, oldId: element.id!);
      element.id = null;
    }

    // Put all the new chats into the ObjectBox database
    Logger.info("Inserting ${chatMigrationMap.size()} chats into ObjectBox database", tag: "OB Migration");
    chatBox.putMany(chats);

    // Get all the chats that we inserted so that we can map to the new IDs
    final newChats = chatBox.getAll();
    Logger.info("Fetched ObjectBox chats, length ${newChats.length}", tag: "OB Migration");
    for (Chat element in newChats) {
      chatMigrationMap.set(element.guid!, newId: element.id!);
    }

    Logger.info("Successfully migrated chats!", tag: "OB Migration");
    return chatMigrationMap;
  }

  MigrationMap migrateHandles(List<dynamic> tableHandles) {
    // Convert list of table rows to a list of Handle objects
    Logger.info("Migrating ${tableHandles.length} handles...", tag: "OB Migration");
    final handles = tableHandles.map((e) => Handle.fromMap(e)).toList();
    final handleMigrationMap = MigrationMap();

    // Create a map using the GUID as the key and the value is a map containing the old and new IDs
    // We also want to reset the element's ID to null so when we insert, it doesn't use the old ID
    for (Handle element in handles) {
      handleMigrationMap.set(element.address, oldId: element.id!);
      element.id = null;
    }

    // Put all the new handles into the ObjectBox database
    Logger.info("Inserting ${handleMigrationMap.size()} handles into ObjectBox database", tag: "OB Migration");
    handleBox.putMany(handles);
    
    // Get all the handles that we inserted so that we can map to the new IDs
    final newHandles = handleBox.getAll();
    Logger.info("Fetched ObjectBox handles, length ${newHandles.length}", tag: "OB Migration");
    for (Handle element in newHandles) {
      handleMigrationMap.set(element.address, newId: element.id!);
    }

    Logger.info("Successfully migrated handles!", tag: "OB Migration");
    return handleMigrationMap;
  }

  MigrationMap migrateMessages(List<dynamic> tableMessages, MigrationMap handleMigrationMap) {
    // Convert list of table rows to a list of Message objects
    Logger.info("Migrating ${tableMessages.length} messages...", tag: "OB Migration");
    final messages = tableMessages.map((e) => Message.fromMap(e)).toList();
    final messageMigrationMap = MigrationMap();

    // Create a map using the GUID as the key and the value is a map containing the old and new IDs
    // We also want to reset the element's ID to null so when we insert, it doesn't use the old ID
    for (Message element in messages) {
      messageMigrationMap.set(element.guid!, oldId: element.id!);
      element.id = null;

      // We also have to migrate the handle ID for the corresponding message to the new one
      if (element.handleId == null || element.handleId == 0) continue;

      // Get the corresponding new ID for the handle, given the old ID
      MigrationItem? ids = handleMigrationMap.get(oldId: element.handleId);
      if (ids != null) {
        element.handleId = ids.newId;
      }
    }

    // Put all the new handles into the ObjectBox database
    Logger.info("Inserting ${messageMigrationMap.size()} messages into ObjectBox database", tag: "OB Migration");
    messageBox.putMany(messages);

    // Get all the handles that we inserted so that we can map to the new IDs
    final newMessages = messageBox.getAll();
    Logger.info("Fetched ObjectBox messages, length ${newMessages.length}", tag: "OB Migration");
    for (Message element in newMessages) {
      messageMigrationMap.set(element.guid!, newId: element.id!);
    }

    Logger.info("Successfully migrated messages!", tag: "OB Migration");
    return messageMigrationMap;
  }

  MigrationMap migrateAttachments(List<dynamic> tableAttachments) {
    // Convert list of table rows to a list of Attachment objects
    Logger.info("Migrating ${tableAttachments.length} attachments...", tag: "OB Migration");
    final attachments = tableAttachments.map((e) => Attachment.fromMap(e)).toList();
    final attachmentMigrationMap = MigrationMap();

    // Create a map using the GUID as the key and the value is a map containing the old and new IDs
    // We also want to reset the element's ID to null so when we insert, it doesn't use the old ID
    for (Attachment element in attachments) {
      attachmentMigrationMap.set(element.guid!, oldId: element.id!);
      element.id = null;
    }

    // Put all the new attachments into the ObjectBox database
    Logger.info("Inserting ${attachmentMigrationMap.size()} attachments into ObjectBox database", tag: "OB Migration");
    attachmentBox.putMany(attachments);
    
    // Get all the handles that we inserted so that we can map to the new IDs
    final newAttachments = attachmentBox.getAll();
    Logger.info("Fetched ObjectBox attachments, length ${newAttachments.length}", tag: "OB Migration");
    for (Attachment element in newAttachments) {
      attachmentMigrationMap.set(element.guid!, newId: element.id!);
    }

    Logger.info("Successfully migrated handles!", tag: "OB Migration");
    return attachmentMigrationMap;
  }

  void migrateChatHandleJoin(List<dynamic> tableData, MigrationMap chatMigrationMap, MigrationMap handleMigrationMap) {
    // Convert all the table rows to ChatHandleJoin objects
    Logger.info("Migrating ${tableData.length} chat-handle joins...", tag: "OB Migration");
    List<ChatHandleJoin> chJoins = tableData.map((e) => ChatHandleJoin.fromMap(e)).toList();

    // Update the object box rows with the new IDs
    int counter = 0;
    for (int i = 0; i < chJoins.length; i++) {
      // Find the corresponding new IDs
      final newChatId = chatMigrationMap.get(oldId: chJoins[i].chatId);
      if (newChatId == null) continue;
      final newHandleId = handleMigrationMap.get(oldId: chJoins[i].handleId);
      if (newHandleId == null) continue;
  
      // Set the new IDs
      chJoins[i].chatId = newChatId.newId!;
      chJoins[i].handleId = newHandleId.newId!;
      counter += 1;
    }

    Logger.info("Replaced $counter chat-handle joins with new ObjectBox IDs", tag: "OB Migration");

    // Lastly, we need to make sure that all the chat participants found in the join table,
    // get added to the corresponding chats.
    final chats = chatBox.getAll();
    for (int i = 0; i < chats.length; i++) {
      // This migration must happen cleanly, we cannot ignore any null errors.
      // The chats must retain all handleIDs previously associated with them

      // Find all the handle IDs for the given chat
      final handleIds = chJoins.where((e) => e.chatId == chats[i].id).map((e) => e.handleId).toList();

      // Fetch all the handle's metadata
      final handles = handleBox.getMany(handleIds);

      // Update the chat with all the handle information
      chats[i].handles.addAll(List<Handle>.from(handles));
    }

    // Update all the chats in the object box database
    chatBox.putMany(chats);
    Logger.info("Successfully migrated chat-handle joins!", tag: "OB Migration");
  }

  void migrateChatMessageJoin(List<dynamic> tableData, MigrationMap chatMigrationMap, MigrationMap messageMigrationMap) {
    // Convert all the table rows to ChatMessageJoin objects
    Logger.info("Migrating ${tableData.length} chat-message joins...", tag: "OB Migration");
    List<ChatMessageJoin> cmJoins = tableData.map((e) => ChatMessageJoin.fromMap(e)).toList();

    // Update the object box rows with the new IDs
    int counter = 0;
    for (int i = 0; i < cmJoins.length; i++) {
      // Find the corresponding new IDs
      final newChatId = chatMigrationMap.get(oldId: cmJoins[i].chatId);
      if (newChatId == null) continue;
      final newMessageId = messageMigrationMap.get(oldId: cmJoins[i].messageId);
      if (newMessageId == null) continue;

      // Set the new IDs
      cmJoins[i].chatId = newChatId.newId!;
      cmJoins[i].messageId = newMessageId.newId!;
      counter += 1;
    }

    Logger.info("Replaced $counter chat-message joins with new ObjectBox IDs", tag: "OB Migration");

    // Lastly, we need to make sure that all the messages found in the join table,
    // have the corresponding chat attached to it
    final messages = messageBox.getAll();
    final toDelete = <int>[];
    for (int i = 0; i < messages.length; i++) {
      // If we can't find a valid chat ID to associate the message with, delete it from ObjectBox
      final chatId = cmJoins.firstWhereOrNull((e) => e.messageId == messages[i].id)?.chatId;
      if (chatId == null) {
        toDelete.add(messages[i].id!);
      } else {
        final chat = chatBox.get(chatId);
        messages[i].chat.target = chat;
      }
    }

    // Update all the messages with their corresponding chat
    messageBox.putMany(messages);
    messageBox.removeMany(toDelete);
    Logger.info("Successfully migrated chat-message joins!", tag: "OB Migration");
  }

  void migrateAttachmentMessageJoin(List<dynamic> tableData, MigrationMap attachmentMigrationMap, MigrationMap messageMigrationMap) {
    // Convert all the table rows to ChatMessageJoin objects
    Logger.info("Migrating ${tableData.length} attachment-message joins...", tag: "OB Migration");
    List<AttachmentMessageJoin> amJoins = tableData.map((e) => AttachmentMessageJoin.fromMap(e)).toList();

    // Set all the new IDs for the join data
    final amjToRemove = <int>[];
    int counter = 0;
    for (int i = 0; i < amJoins.length; i++) {
      // Find the corresponding new IDs
      final newAttachmentId = attachmentMigrationMap.get(oldId: amJoins[i].attachmentId);
      final newMessageId = messageMigrationMap.get(oldId: amJoins[i].messageId);

      // If we don't have new message or attachment IDs, we need to add the index to a list
      // to be deleted later
      if (newAttachmentId != null && newMessageId != null) {
        amJoins[i].attachmentId = newAttachmentId.newId!;
        amJoins[i].messageId = newMessageId.newId!;
      } else {
        amjToRemove.add(i);
      }

      counter += 1;
    }

    // Remove all the join rows that do not have an associated message or attachment
    for (int i in amjToRemove) {
      amJoins.removeAt(i);
    }

    Logger.info("Replaced $counter attachment-message joins with new ObjectBox IDs", tag: "OB Migration");

    // Lastly, we need to make sure that all the attachments found in the join table,
    // have the corresponding messages attached to it
    final attachments = attachmentBox.getAll();
    final toDelete = <int>[];
    for (int i = 0; i < attachments.length; i++) {
      // if we can't find a valid messageID to associate the attachment with, delete it
      final messageId = amJoins.firstWhereOrNull((e) => e.attachmentId == attachments[i].id)?.messageId;
      if (messageId == null) {
        toDelete.add(attachments[i].id!);
      } else {
        final message = messageBox.get(messageId);
        attachments[i].message.target = message;
      }
    }

    // Update all the attachments with their corresponding message
    attachmentBox.putMany(attachments);
    attachmentBox.removeMany(toDelete);
    Logger.info("Successfully migrated attachment-message joins!", tag: "OB Migration");
  }
}
