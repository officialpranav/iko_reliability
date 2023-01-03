import 'dart:typed_data';

import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

const frequencyUnits = ['D', 'W', 'M', 'Y'];

double parseTime(dynamic text) {
  var hour = 0.0;
  if (text is String) {
    var temp = text.split(':');
    hour = double.parse(temp[0]);
    hour = hour + (double.parse(temp[1]) / 60.0);
  } else {
    hour = text * 1.0;
  }
  return hour;
}

class NoPMException implements Exception {
  String errMsg() => 'No PMs detected in the spreadsheet';
}

class JobCraft {
  final String laborType;
  final int quantity;
  final double hours;

  const JobCraft({
    required this.laborType,
    required this.quantity,
    required this.hours,
  });
}

class JobMaterial {
  final String itemNumber;
  final int quantity;
  final double? cost;

  const JobMaterial({
    required this.itemNumber,
    required this.quantity,
    this.cost,
  });
}

class JobService {
  final String itemNumber;
  final String vendorId;
  final double? cost;

  const JobService({
    required this.itemNumber,
    required this.vendorId,
    this.cost,
  });
}

class JobTask {
  final int jptask;
  final String description;
  final String? assetNumber;
  final String? metername;
  final String? longdescription;

  const JobTask({
    required this.jptask,
    required this.description,
    required this.assetNumber,
    this.metername,
    this.longdescription,
  });
}

class ProcessedTemplate {
  String? pmNumber;
  String? pmName;
  String? jpNumber;
  List<String>? replaceable;

  ProcessedTemplate({
    this.pmName,
    this.pmNumber,
    this.jpNumber,
    this.replaceable,
  });
}

class ParsedTemplate {
  List<String> assets;
  String? siteId;
  String? frequencyUnit;
  int? frequency;
  String? workOrderType;
  String? processCondition;
  List<JobCraft> crafts;
  List<JobMaterial> materials;
  List<JobService> services;
  List<JobTask> tasks;
  String? nextDueDate;
  String pmNumber;
  String pmName;
  String? pmPackageNumber;
  String? routeCode;
  String? routeName; // TODO replace this with loaded value list + editor later
  String? pmAsset; // the parent asset specified for the PM
  String? suggestedPmNumber;
  String? suggestedPmName;

  ParsedTemplate({
    List<String>? assets,
    this.siteId,
    this.frequencyUnit,
    this.frequency,
    this.workOrderType,
    this.processCondition,
    List<JobCraft>? crafts,
    List<JobMaterial>? materials,
    this.nextDueDate,
    required this.pmNumber,
    required this.pmName,
    this.pmPackageNumber,
    this.routeCode,
    this.routeName,
    this.suggestedPmName,
    this.pmAsset,
    this.suggestedPmNumber,
    List<JobService>? services,
    List<JobTask>? tasks,
  })  : assets = assets ?? [],
        crafts = crafts ?? [],
        materials = materials ?? [],
        services = services ?? [],
        tasks = tasks ?? [];

  Map<dynamic, dynamic> fromExcel(List<dynamic> stuff) {
    Uint8List bytes = stuff[0];
    String filename = stuff[1];
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    var pmTemplates = {};
    var pmNumber = 0;
    var readTasks = false;
    var readCraft = false;
    var readMaterials = false;
    var readService = false;
    var readRouteAsset = false;
    pmTemplates[filename] = {};
    for (var sheet in decoder.tables.keys) {
      if (sheet != 'Main') {
        continue; //ignore the non template sheets
      }
      for (var i = 0; i < decoder.tables[sheet]!.maxRows; i++) {
        var row = decoder.tables[sheet]!.rows[i];
        if (row[0] == "DON’T REMOVE THIS LINE") {
          continue;
        }
        if (row[0] == 'PM Asset/ Parent (Route)*:') {
          readTasks = false;
          readCraft = false;
          readMaterials = false;
          readService = false;
          readRouteAsset = false;
          var nextRow = decoder.tables[sheet]!.rows[i + 1];
          pmNumber++;
          String workOrderType = nextRow[6].substring(0, 3);
          if (workOrderType == 'LC1') {
            workOrderType = 'LIF';
          }
          var nextDate;
          if (nextRow[2] != null) {
            if (nextRow[2] is String) {
              nextDate = nextRow[2].substring(0, 10);
            } else {
              nextDate = DateTime.fromMillisecondsSinceEpoch(
                      (nextRow[2] - 25569) * 86400000,
                      isUtc: true)
                  .toString()
                  .substring(0, 10);
            }
          }
          pmTemplates[filename][pmNumber] = ParsedTemplate(
            nextDueDate: nextDate,
            siteId: nextRow[3].toString().toUpperCase(),
            frequencyUnit: frequencyUnits.contains(nextRow[4].substring(0, 1))
                ? nextRow[4].substring(0, 1)
                : null,
            frequency: nextRow[5],
            workOrderType: workOrderType,
            processCondition: nextRow[7].substring(0, 4),
            pmAsset: nextRow[0],
            pmName: nextRow[8] ?? 'Generating Name...',
            pmNumber:
                decoder.tables[sheet]!.rows[i + 2][8] ?? 'Generating Number...',
            suggestedPmName: nextRow[8],
            suggestedPmNumber: decoder.tables[sheet]!.rows[i + 2][8],
            routeName:
                (nextRow[9] == 'Select Route (Optional)' ? null : nextRow[9]),
            routeCode: (nextRow[9] == 'Select Route (Optional)'
                ? null
                : decoder.tables[sheet]!.rows[i + 2][9]),
          );
        }
        if (row[7] != null && readTasks) {
          pmTemplates[filename][pmNumber].tasks.add(JobTask(
              jptask: row[6], // TODO show error for missing jptask number
              description: row[7],
              assetNumber: row[4],
              metername: row[5],
              longdescription: row[8]));
          if (row[4] != null) {
            pmTemplates[filename][pmNumber].assets.add(row[4]);
          }
        }
        if (row[3] != null && readRouteAsset) {
          pmTemplates[filename][pmNumber].assets.add(row[3]);
        }
        if (row[0] == 'Materials (Mapics Number)') {
          readCraft = false;
          readMaterials = true;
          continue;
        }
        if (row[0] == 'Services (Mapics Number)') {
          readCraft = false;
          readService = true;
          continue;
        }
        if (row[1] != null && readCraft) {
          pmTemplates[filename][pmNumber].crafts.add(JobCraft(
              laborType: row[0].substring(row[0].length - 1),
              quantity: row[1],
              hours: parseTime(row[2])));
        }

        if (row[0] != null && readMaterials) {
          pmTemplates[filename][pmNumber].materials.add(JobMaterial(
              itemNumber: row[0].toString(),
              quantity: row[1] ?? 1,
              cost: row[2]?.toDouble()));
        }
        if (row[0] != null && readService) {
          pmTemplates[filename][pmNumber].services.add(JobService(
              itemNumber: row[0].toString(),
              vendorId: row[2],
              cost: row[1].toDouble()));
        }
        if (row[0] == 'Craft (Labour Code(Optional))') {
          readTasks = true;
          readCraft = true;
          continue;
        }

        if (row[3] == 'Route Assets (one per cell):' ||
            row[3] == 'Task Route Assets (one per cell):') {
          readRouteAsset = true;
        }
      }
    }
    if (pmTemplates.isEmpty) {
      throw NoPMException();
    }
    return pmTemplates;
  }
}
