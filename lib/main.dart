import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(AudioRecorderApp());
}

class AudioRecorderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: RecorderScreen(),
    );
  }
}

class RecorderScreen extends StatefulWidget {
  @override
  _RecorderScreenState createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  String? _playingPath;
  Timer? _timer;
  int _recordDuration = 0;
  List<Map<String, String>> _recordings = [];

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initializeRecorder();
    _loadRecordings();
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  Future<void> _startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    _recordingPath =
    '${dir.path}/recorded_audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder!.startRecorder(toFile: _recordingPath);
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      if (_recordingPath != null) {
        _saveRecording(_recordingPath!, _recordDuration);
      }
    });
  }

  void _saveRecording(String path, int duration) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    _recordings.insert(0, {
      "path": path,
      "duration": duration.toString(),
      "date": formattedDate
    });

    await prefs.setString('recordings', jsonEncode(_recordings));
    setState(() {});
  }

  Future<void> _loadRecordings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('recordings');

    if (savedData != null) {
      List<dynamic> decodedData = jsonDecode(savedData);
      _recordings = decodedData.map((e) => Map<String, String>.from(e)).toList();
    }

    setState(() {});
  }

  Future<void> _playRecording(String path) async {
    if (_isPlaying && _playingPath == path) {
      await _player!.stopPlayer();
      setState(() {
        _isPlaying = false;
        _playingPath = null;
      });
    } else {
      await _player!.startPlayer(
        fromURI: path,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
            _playingPath = null;
          });
        },
      );
      setState(() {
        _isPlaying = true;
        _playingPath = path;
      });
    }
  }

  void _shareRecording(String path) {
    Share.shareFiles([path]);
  }

  Future<void> _showDeleteDialog(int index) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Recording"),
        content: Text("Are you sure you want to delete this recording?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog without deleting
            },
            child: Text("No", style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              _deleteRecording(index); // Delete if user confirms
              Navigator.pop(context);
            },
            child: Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteRecording(int index) async {
    File(_recordings[index]["path"]!).deleteSync();
    _recordings.removeAt(index);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('recordings', jsonEncode(_recordings));

    setState(() {});
  }


  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          forceMaterialTransparency: true,
          title: Text('Recordings')),
      body: Column(
        children: [
          SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text(
                  _isRecording ? _formatDuration(_recordDuration) : '00:00',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  child: Center(
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 50,
                    ),
                  ),
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  onPressed: () async {
                    _isRecording ? await _stopRecording() : await _startRecording();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                bool isCurrentlyRecording =
                    _isRecording && _recordings[index]["path"] == _recordingPath;
                bool isCurrentlyPlaying =
                    _isPlaying && _recordings[index]["path"] == _playingPath;

                return Container(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: isCurrentlyRecording ? Colors.red : Colors.blue,
                        child: Icon(
                          isCurrentlyRecording ? Icons.fiber_manual_record : Icons.music_note,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recording ${index + 1}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Date: ${_recordings[index]["date"]}',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                'Duration: ${_formatDuration(int.parse(_recordings[index]["duration"]!))}',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.green,
                            ),
                            onPressed: () => _playRecording(_recordings[index]["path"]!),
                          ),
                          IconButton(
                            icon: Icon(Icons.share, color: Colors.blue),
                            onPressed: () => _shareRecording(_recordings[index]["path"]!),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteDialog(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _player!.closePlayer();
    _timer?.cancel();
    super.dispose();
  }
}
