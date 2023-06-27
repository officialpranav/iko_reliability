import 'dart:async';
import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:iko_reliability_flutter/admin/db_drift.dart';
import 'package:iko_reliability_flutter/admin/end_drawer.dart';
import 'package:iko_reliability_flutter/admin/upload_maximo.dart';
import 'package:iko_reliability_flutter/creation/asset_creation_notifier.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';

import '../main.dart';

var celltest = PlutoCell(value: 0);
var rowtest = PlutoRow(cells: {
  'assetnum': celltest,
  'description': celltest,
  'priority': celltest,
  'hierarchy': celltest,
  'id': celltest,
  'site': celltest,
},
  type: PlutoRowType.group(children: FilteredList<PlutoRow>(initialList: [])),);
var rowTestTest = PlutoRow(
  cells: {
  'assetnum': celltest,
  'description': celltest,
  'priority': celltest,
  'hierarchy': celltest,
  'id': celltest,
  'site': celltest,
  },
  type: PlutoRowType.group(children: FilteredList<PlutoRow>(initialList: [rowtest])),
);

class AssetPage extends StatefulWidget {
  const AssetPage({Key? key}) : super(key: key);
  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  Key? currentRowKey;
  List<PlutoColumn> columns = [];
  List<PlutoRow> rows = [];
  Map<String, Asset> siteAssets = {};
  Map<String, List<Asset>> parentAssets = {};

  late PlutoGridStateManager stateManager;
  final assetTextController = TextEditingController();

  @override
  void dispose() {
    assetTextController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    columns.addAll([
      PlutoColumn(
        title: '',
        field: 'id',
        type: PlutoColumnType.number(),
        readOnly: true,
        hide: true,
      ),
      PlutoColumn(
        width: 300,
        title: 'Hierarchy',
        field: 'hierarchy',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        width: 100,
        title: 'Asset Number',
        field: 'assetnum',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        title: 'Description',
        field: 'description',
        type: PlutoColumnType.text(),
        width: 500,
      ),
      PlutoColumn(
        width: 100,
        readOnly: true,
        enableAutoEditing: false,
        title: 'Priority',
        field: 'priority',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        width: 100,
        readOnly: true,
        enableAutoEditing: false,
        title: 'Site',
        field: 'site',
        type: PlutoColumnType.text(),
      ),
    ]);
    changeSite('GX');
  }

  void changeSite(String site) {
    if (site == 'NONE') {
      return;
    }
    _loadData(site).then((fetchedRows) {
      PlutoGridStateManager.initializeRowsAsync(
        columns,
        fetchedRows,
      ).then((value) {
        stateManager.refRows.clear();
        stateManager.refRows.addAll(value);
        stateManager.setShowLoading(false);
        stateManager.notifyListeners();
        // workaround since setting the group as expanded does not expand first row
        stateManager.toggleExpandedRowGroup(rowGroup: stateManager.rows.first);
        stateManager.toggleExpandedRowGroup(rowGroup: stateManager.rows.first);
      });
    });
  }

  Future<List<PlutoRow>> _loadData(String site) async {
    siteAssets.clear();
    parentAssets.clear();
    final dbrows = await database!
        .getSiteAssets(site); //todo make it able to load other sites
    for (var row in dbrows) {
      siteAssets[row.assetnum] = row;
      if (parentAssets.containsKey(row.parent)) {
        parentAssets[row.parent]!.add(row);
      } else {
        parentAssets[row.parent ?? "Top"] = [row];
      }
    }
    return getChilds('Top');
  }

  List<PlutoRow> getChilds(String parent) {
    List<PlutoRow> rows = [];
    if (parentAssets.containsKey(parent)) {
      for (var child in parentAssets[parent]!) {
        rows.add(PlutoRow(
          cells: {
            'assetnum': PlutoCell(value: child.assetnum),
            'description': PlutoCell(value: child.description),
            'priority': PlutoCell(value: child.priority),
            'hierarchy': PlutoCell(
                value: child.hierarchy!.substring(child.hierarchy!.length - 5)),
            'id': PlutoCell(value: child.id),
            'site': PlutoCell(value: child.siteid),
          },
          type: PlutoRowType.group(
              expanded: true,
              children: FilteredList<PlutoRow>(
                  initialList: getChilds(child.assetnum))),
        ));
      }
    }
    return rows;
  }

  void gridHandler() {
    if (stateManager.currentRow == null) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetCreationNotifier>(
        builder: (context, assetCreationNotifier, child) {
      changeSite(assetCreationNotifier.selectedSite);
      return Scaffold(
        appBar: AppBar(
          title: const Text("Maximo Asset Creator"),
        ),
        endDrawer: const EndDrawer(),
        body: Column(
          children: <Widget>[
            ElevatedButton(
              child: const Text('print assets'),
              onPressed: () async {
                final assets = await database!.getSiteAssets(assetCreationNotifier.selectedSite);
                debugPrint(assets.toString());
                //print(assetCreationNotifier.selectedSite);
              },
            ),
            SizedBox(
              //color: const Color.fromARGB(55, 0, 0, 0),
              height: 800,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: PlutoGrid(
                  columns: columns,
                  rows: rows,
                  onLoaded: (PlutoGridOnLoadedEvent event) {
                    stateManager = event.stateManager;
                    event.stateManager.addListener(gridHandler);
                    stateManager.setShowColumnFilter(true);
                    stateManager.setRowGroup(PlutoRowGroupTreeDelegate(
                      resolveColumnDepth: (column) =>
                          stateManager.columnIndex(column),
                      showText: (cell) => true,
                      showCount: false,
                      showFirstExpandableIcon: true,
                    ));
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: const Text('Create Asset'),
                    content: Container(
                      height: 50,
                      child: Column(children: [
                        TextField(
                            controller: assetTextController,
                            decoration: const InputDecoration(
                              hintText: 'Parent Asset Number',
                            )),
                      ]),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, 'Cancel');
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          var parentAsset =
                              assetTextController.text.toUpperCase();

                          if (!siteAssets.containsKey(parentAsset)) {
                            return;
                          }

                          var rowIdx = siteAssets.keys
                              .toList()
                              .indexOf(assetTextController.text.toUpperCase());

                          if (rowIdx == -1) {
                            return;
                          }

                          var newRow = PlutoRow(
                            cells: {
                              'assetnum': PlutoCell(value: 'a'),
                              'description': PlutoCell(value: 'a'),
                              'priority': PlutoCell(value: 'a'),
                              'hierarchy': PlutoCell(value: 'a'),
                              'id': PlutoCell(value: 'a'),
                              'site': PlutoCell(
                                  value: assetCreationNotifier.selectedSite),
                            },
                            type: PlutoRowType.group(
                                children:
                                    FilteredList<PlutoRow>(initialList: [])),
                          );

                          if (parentAssets.containsKey(parentAsset)) {
                            stateManager.insertRows(rowIdx + 1, [newRow]);
                          } else {
                            var parentCells =
                                stateManager.refRows[rowIdx].cells;
                            var newParentRow = PlutoRow(
                              cells: parentCells,
                              type: PlutoRowType.group(
                                expanded: false,
                                children: FilteredList<PlutoRow>(
                                  initialList: [
                                    PlutoRow(
                                      cells: {
                                        'assetnum': PlutoCell(value: 'a'),
                                        'description': PlutoCell(value: 'a'),
                                        'priority': PlutoCell(value: 'a'),
                                        'hierarchy': PlutoCell(value: 'a'),
                                        'id': PlutoCell(value: 'a'),
                                        'site': PlutoCell(
                                            value: assetCreationNotifier
                                                .selectedSite),
                                      },
                                      type: PlutoRowType.group(
                                          children: FilteredList<PlutoRow>(
                                              initialList: [])),
                                    )
                                  ],
                                ),
                              ),
                            );
                            //stateManager
                            //.removeRows([stateManager.refRows[rowIdx]]);
                            stateManager
                                .insertRows(rowIdx + 1, [rowTestTest]);
                            //stateManager.insertRows(rowIdx, [newRow]);
                            stateManager.notifyListeners();
                          }

                          Navigator.pop(context, 'OK');
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  )),
          label: const Text('Create Asset'),
        ),
      );
    });
  }
}
