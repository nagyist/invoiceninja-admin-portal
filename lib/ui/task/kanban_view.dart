import 'package:boardview/board_item.dart';
import 'package:boardview/board_list.dart';
import 'package:boardview/boardview.dart';
import 'package:boardview/boardview_controller.dart';
import 'package:flutter/material.dart';
import 'package:invoiceninja_flutter/utils/app_context.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/app/app_actions.dart';
import 'package:invoiceninja_flutter/ui/app/forms/decorated_form_field.dart';
import 'package:invoiceninja_flutter/ui/task/kanban_view_vm.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:timeago/timeago.dart' as timeago;

class KanbanView extends StatefulWidget {
  const KanbanView({
    Key key,
    @required this.viewModel,
  }) : super(key: key);

  final KanbanVM viewModel;

  @override
  _KanbanViewState createState() => _KanbanViewState();
}

class _KanbanViewState extends State<KanbanView> {
  final _boardViewController = new BoardViewController();

  List<TaskStatusEntity> _statuses = [];
  Map<String, List<TaskEntity>> _tasks = {};

  @override
  void initState() {
    super.initState();
    print('## initState: ${_statuses.length}');

    final state = widget.viewModel.state;
    _statuses = state.taskStatusState.list
        .map((statusId) => state.taskStatusState.get(statusId))
        .where((status) => status.isActive)
        .toList();
    _statuses.sort((statusA, statusB) {
      if (statusA.statusOrder == statusB.statusOrder) {
        return statusB.updatedAt.compareTo(statusA.updatedAt);
      } else {
        return (statusA.statusOrder ?? 99999)
            .compareTo(statusB.statusOrder ?? 99999);
      }
    });

    widget.viewModel.taskList.forEach((taskId) {
      final task = state.taskState.map[taskId];
      if (task.isActive && task.statusId.isNotEmpty) {
        final status = state.taskStatusState.get(task.statusId);
        if (!_tasks.containsKey(status.id)) {
          _tasks[status.id] = [];
        }
        _tasks[status.id].add(task);
      }
    });

    _tasks.forEach((key, value) {
      _tasks[key].sort((taskA, taskB) {
        if (taskA.statusOrder == taskB.statusOrder) {
          return taskB.updatedAt.compareTo(taskA.updatedAt);
        } else {
          return (taskA.statusOrder ?? 99999)
              .compareTo(taskB.statusOrder ?? 99999);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    print('## BUILD: ${_statuses.length}');

    final boardList = _statuses.map((status) {
      return BoardList(
        backgroundColor: Theme.of(context).cardColor,
        headerBackgroundColor: Theme.of(context).cardColor,
        onDropList: (endIndex, startIndex) {
          if (endIndex == startIndex) {
            return;
          }

          setState(() {
            final status = _statuses[startIndex];
            _statuses.removeAt(startIndex);
            _statuses = [
              ..._statuses.sublist(0, endIndex),
              status,
              ..._statuses.sublist(endIndex),
            ];
          });

          widget.viewModel.onStatusOrderChanged(context, status.id, endIndex);
        },
        header: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                  '${status.statusOrder} - ${status.name} - ${timeago.format(DateTime.fromMillisecondsSinceEpoch(status.updatedAt * 1000))}'),
            ),
          ),
        ],
        footer: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton(
              child: Text(AppLocalization.of(context).newTask),
              onPressed: () {
                //
              },
            ),
          ),
        ),
        items: (_tasks[status.id] ?? [])
            .map(
              (task) => BoardItem(
                item: _TaskCard(
                  task: task,
                  onSavePressed: (description) {
                    widget.viewModel
                        .onSaveTaskPressed(context, task.id, description);
                  },
                ),
                onDropItem: (
                  int listIndex,
                  int itemIndex,
                  int oldListIndex,
                  int oldItemIndex,
                  BoardItemState state,
                ) {
                  if (listIndex == oldListIndex && itemIndex == oldItemIndex) {
                    return;
                  }

                  final oldStatus = _statuses[oldListIndex];
                  final newStatus = _statuses[listIndex];
                  final task = _tasks[status.id][oldItemIndex];

                  setState(() {
                    if (_tasks.containsKey(oldStatus.id) &&
                        _tasks[oldStatus.id].contains(task)) {
                      _tasks[oldStatus.id].remove(task);
                    }

                    if (!_tasks.containsKey(newStatus.id)) {
                      _tasks[newStatus.id] = [];
                    }

                    _tasks[newStatus.id] = [
                      ..._tasks[newStatus.id].sublist(0, itemIndex),
                      task,
                      ..._tasks[newStatus.id].sublist(itemIndex),
                    ];
                  });

                  widget.viewModel.onTaskOrderChanged(
                      context, task.id, newStatus.id, itemIndex);
                },
              ),
            )
            .toList(),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: BoardView(
        boardViewController: _boardViewController,
        lists: boardList,
        dragDelay: 1,
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    @required this.task,
    @required this.onSavePressed,
  });
  final TaskEntity task;
  final Function(String) onSavePressed;

  @override
  __TaskCardState createState() => __TaskCardState();
}

class __TaskCardState extends State<_TaskCard> {
  bool _isEditing = false;
  String _description = '';

  @override
  void initState() {
    super.initState();

    _description = widget.task.description;
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context);

    if (_isEditing) {
      return Card(
        color: Theme.of(context).backgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedFormField(
                autofocus: true,
                initialValue: widget.task.description,
                minLines: 4,
                maxLines: 4,
                onChanged: (value) => _description = value,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: Text(localization.cancel),
                ),
                TextButton(
                  onPressed: () {
                    viewEntity(
                        appContext: context.getAppContext(),
                        entity: widget.task);
                  },
                  child: Text(localization.view),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onSavePressed(_description.trim());
                  },
                  child: Text(localization.save),
                ),
              ],
            )
          ],
        ),
      );
    }

    return InkWell(
      child: Card(
        color: Theme.of(context).backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
              '${widget.task.statusOrder} - ${widget.task.id} - ${timeago.format(DateTime.fromMillisecondsSinceEpoch(widget.task.updatedAt * 1000))}'),
        ),
      ),
      onTap: () {
        setState(() {
          _isEditing = true;
        });
      },
    );
  }
}