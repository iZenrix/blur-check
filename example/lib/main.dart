import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blur_check/blur_check.dart';

void main() {
  runApp(const BlurDetectorExampleApp());
}

class BlurDetectorExampleApp extends StatelessWidget {
  const BlurDetectorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blur_check',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6F5B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class _Sample {
  const _Sample(this.label, this.assetPath);

  final String label;
  final String assetPath;
}

const _samples = <_Sample>[
  _Sample('Sharp document', 'assets/samples/sharp.jpg'),
  _Sample('Light blur', 'assets/samples/blur-light.jpg'),
  _Sample('Heavy blur', 'assets/samples/blur-heavy.jpg'),
  _Sample('Motion blur', 'assets/samples/motion-blur.jpg'),
  _Sample('Dark sharp', 'assets/samples/dark-sharp.jpg'),
  _Sample('Dark blur', 'assets/samples/dark-blur.jpg'),
  _Sample('Low texture', 'assets/samples/low-texture-sharp.jpg'),
];

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  double _threshold = 45;
  int _selectedIndex = 0;
  bool _loading = false;
  BlurDetectionResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyzeSelected();
  }

  Future<void> _analyzeSelected() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sample = _samples[_selectedIndex];
      final bytes = (await rootBundle.load(
        sample.assetPath,
      )).buffer.asUint8List();
      final detector = BlurDetector(
        config: BlurDetectorConfig(
          threshold: _threshold,
          maxAnalysisDimension: 720,
          useIsolate: true,
          isolateMinBytes: 0,
        ),
      );
      final result = await detector.analyzeBytes(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _result = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sample = _samples[_selectedIndex];
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('blur_check'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Offline sharpness check',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a sample photo, tune the threshold, and inspect score + warnings. '
            'Calibrate threshold for your real camera photos before production use.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(sample.assetPath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _samples.length; i++)
                ChoiceChip(
                  label: Text(_samples[i].label),
                  selected: i == _selectedIndex,
                  onSelected: (_) {
                    setState(() => _selectedIndex = i);
                    _analyzeSelected();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Threshold: ${_threshold.toStringAsFixed(0)}'),
          Slider(
            value: _threshold,
            min: 0,
            max: 100,
            divisions: 20,
            label: _threshold.toStringAsFixed(0),
            onChanged: (value) {
              setState(() => _threshold = value);
            },
            onChangeEnd: (_) => _analyzeSelected(),
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (result != null) ...[
            _ResultCard(result: result, threshold: _threshold),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.threshold});

  final BlurDetectionResult result;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = result.isBlurred ? scheme.error : scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.isBlurred ? 'Too blurry — retake' : 'Acceptable sharpness',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _row('Score', result.score.toStringAsFixed(1)),
            _row('Threshold', threshold.toStringAsFixed(0)),
            _row(
              'Analysis size',
              '${result.analysisWidth}×${result.analysisHeight}',
            ),
            _row(
              'Original size',
              '${result.originalWidth}×${result.originalHeight}',
            ),
            const Divider(height: 24),
            Text('Metrics', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _row(
              'Laplacian variance',
              result.metrics.laplacianVariance.toStringAsFixed(2),
            ),
            _row('Edge density', result.metrics.edgeDensity.toStringAsFixed(4)),
            _row('Contrast', result.metrics.contrast.toStringAsFixed(2)),
            _row(
              'Mean brightness',
              result.metrics.meanBrightness.toStringAsFixed(3),
            ),
            const SizedBox(height: 12),
            Text(
              'Warnings: ${result.warnings.isEmpty ? 'none' : result.warnings.join(', ')}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
