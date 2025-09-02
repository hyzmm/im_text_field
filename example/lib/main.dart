import 'package:flutter/material.dart';
import 'package:im_text_field/im_text_field.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'IM TextField Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

typedef DataType = (String, String);

class _MyHomePageState extends State<MyHomePage> {
  final _tags = [('tag1', '001'), ('tag2', '002'), ('tag3', '003')];
  final _mentions = [('user1', '101'), ('user2', '102'), ('user3', '103')];

  late ImEditingController _controller;
  List<(String, String)> matches = [];
  final _focusNode = FocusNode();

  @override
  void initState() {
    _controller = ImEditingController({
      '@': ImTrigger<(String, String)>(
        onTrigger: _onMatchMention,
        builder: (context, data, style, withComposing) =>
            Text('@${data.$1}', style: style!.copyWith(color: Colors.blue)),
      ),
      '#': ImTrigger<(String, String)>(
        onTrigger: _onMatchTag,
        builder: (context, data, style, withComposing) =>
            Text('#${data.$1}', style: style!.copyWith(color: Colors.green)),
      ),
    });
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return ListTile(
                  title: Text(match.$1),
                  subtitle: Text(match.$2),
                  onTap: () {
                    final triggerChar = matches == _tags ? '#' : '@';
                    final match = matches[index];
                    _controller.insertTriggeredValue(
                      triggerChar,
                      match,
                      plainText: "$triggerChar${match.$1}",
                    );
                    _focusNode.requestFocus();

                    setState(() {
                      matches = [];
                    });
                  },
                );
              },
            ),
          ),
          // some icons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              spacing: 8,
              children:
                  [
                        (Icons.abc, 'abc'),
                        (Icons.ac_unit, 'ac_unit'),
                        (Icons.alarm, 'alarm'),
                      ]
                      .map(
                        (icon) => IconButton.filled(
                          onPressed: () {
                            _controller.insertWidgetSpan(
                              icon.$2,
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(icon.$1, color: Colors.blue),
                              ),
                              plainText: ":${icon.$2}:",
                            );
                          },
                          icon: Icon(icon.$1),
                        ),
                      )
                      .toList(),
            ),
          ),
          ImTextField(
            decoration: InputDecoration(
              contentPadding: EdgeInsets.all(16),
              fillColor: Colors.blue[50],
              filled: true,
            ),
            style: TextStyle(color: Colors.black),
            focusNode: _focusNode,
            controller: _controller,
            maxLines: null,
            onFinishMatching: () => setState(() {
              matches = [];
            }),
          ),
        ],
      ),
    );
  }

  void _onMatchMention(String value) {
    if (value.isEmpty) {
      matches = _mentions;
    } else {
      matches = _mentions
          .where((mention) => mention.$1.contains(value))
          .toList();
    }
    setState(() {});
  }

  void _onMatchTag(String value) {
    if (value.isEmpty) {
      matches = _tags;
    } else {
      matches = _tags.where((tag) => tag.$1.contains(value)).toList();
    }
    setState(() {});
  }
}
