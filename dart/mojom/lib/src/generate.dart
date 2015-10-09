// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library generates Mojo bindings for a Dart package.

library generate;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:mojom/src/utils.dart';
import 'package:path/path.dart' as path;

part 'generate_dot_mojoms.dart';

class MojomGenerator {
  static Counter _genMs;
  final bool _errorOnDuplicate;
  final bool _verbose;
  final bool _dryRun;
  final Directory _mojoSdk;

  Map<String, String> _duplicateDetection;
  int _generationMs;

  MojomGenerator(this._mojoSdk,
      {bool errorOnDuplicate: true,
      bool verbose: false,
      bool profile: false,
      bool dryRun: false})
      : _errorOnDuplicate = errorOnDuplicate,
        _verbose = verbose,
        _dryRun = dryRun,
        _generationMs = 0,
        _duplicateDetection = new Map<String, String>() {
    if (_genMs == null) {
      _genMs = new Counter("mojom generation",
          "Time spent waiting for bindings generation script in ms.");
      Metrics.register(_genMs);
    }
  }

  /// Generate bindings for [pacakge]. Fail if there is no .mojoms file, or if
  /// the .mojoms file refers to .mojom files lacking a DartPackage annotation
  /// for [pacakge]
  generateForPackage(Directory package) async {
    Directory packageRoot = new Directory(path.join(package.path, 'packages'));
    File mojomsFile = new File(path.join(package.path, '.mojoms'));
    if (!(await mojomsFile.exists())) {
      throw new FetchError("No .mojoms file found: $mojomsFile");
    }

    Directory temp = await package.createTemp();
    try {
      // Count the .mojom files and find the modification time of the most
      // recently modified one.
      List fetchedMojomsInfo =
          await _fetchFromDotMojoms(package.uri, temp, mojomsFile);
      DateTime mojomTime = fetchedMojomsInfo[0];
      int mojomCount = fetchedMojomsInfo[1];

      // Count the .mojom.dart files, and find the modification time of the
      // least recently modified one.
      List mojomDartInfo = await _findOldestMojomDart(package);
      DateTime mojomDartTime = mojomDartInfo[0];
      int mojomDartCount = mojomDartInfo[1];

      // If we don't have enough .mojom.dart files, or if a .mojom file is
      // newer than the oldest .mojom.dart file, then regenerate.
      if ((mojomDartCount < mojomCount) ||
          _shouldRegenerate(mojomTime, mojomDartTime)) {
        if (_verbose) print("Regenerating for package $package");
        await for (var dir in temp.list()) {
          if (dir is! Directory) continue;
          var mojomDir = new Directory(path.join(dir.path, 'mojom'));
          if (_verbose) print("pathSegments = ${package.uri.pathSegments}");
          await _generateForMojomDir(mojomDir, packageRoot,
              packageName: package.uri.pathSegments.lastWhere((s) => s != ""));
        }
        // Delete any .mojom.dart files that are still older than mojomTime.
        _deleteOldMojomDart(package, mojomTime);
      } else if (_verbose) print("Not regenerating for package $package");
    } finally {
      // Fetching .mojom files and .mojom.dart generation can throw. If that
      // happens, delete the temporary directory.
      await temp.delete(recursive: true);
    }
  }

  /// Under [package]/lib, returns the oldest modification time for a
  /// .mojom.dart file.
  _findOldestMojomDart(Directory package) async {
    int mojomDartCount = 0;
    DateTime oldestModTime;
    Directory libDir = new Directory(path.join(package.path, 'lib'));
    if (!await libDir.exists()) return null;
    await for (var file in libDir.list(recursive: true)) {
      if (file is! File) continue;
      if (!isMojomDart(file.path)) continue;
      DateTime modTime = (await file.stat()).modified;
      if ((oldestModTime == null) || oldestModTime.isAfter(modTime)) {
        oldestModTime = modTime;
      }
      mojomDartCount++;
    }
    return [oldestModTime, mojomDartCount];
  }

  // Delete .mojom.dart files under package that are [olderThanThis].
  _deleteOldMojomDart(Directory package, DateTime olderThanThis) async {
    Directory libDir = new Directory(path.join(package.path, 'lib'));
    assert(await libDir.exists());
    await for (var file in libDir.list(recursive: true)) {
      if (file is! File) continue;
      if (!isMojomDart(file.path)) continue;
      DateTime modTime = (await file.stat()).modified;
      if (modTime.isBefore(olderThanThis)) {
        if (_verbose) print("Deleting stale .mojom.dart: $file");
        await file.delete();
      }
    }
  }

  /// If the .mojoms file or the newest .mojom is newer than the oldest
  /// .mojom.dart, then regenerate everything.
  bool _shouldRegenerate(DateTime mojomTime, DateTime mojomDartTime) {
    return (mojomTime == null) ||
        (mojomDartTime == null) ||
        mojomTime.isAfter(mojomDartTime);
  }

  /// Given a .mojoms file in |mojomsFile|, fetch the listed .mojom files and
  /// store them in a directory tree rooted at |destination|. Relative file URIs
  /// are resolved relative to |base|. The "mojom" directories populated under
  /// |destination| are suitable for passing to |generateForMojomDir| above.
  ///
  /// The .mojoms file should be formatted as follows:
  /// '''
  /// root: https://www.example.com/mojoms
  /// path/to/some/mojom1.mojom
  /// path/to/some/other/mojom2.mojom
  ///
  /// root: https://www.example-two.com/mojoms
  /// path/to/example/two/mojom1.mojom
  /// ...
  ///
  /// root: file:///absolute/path/to/mojoms
  /// ...
  ///
  /// root /some/absolute/path
  /// ...
  ///
  /// root: ../../path/relative/to/|base|/mojoms
  /// ...
  ///
  /// Lines beginning with '#' are ignored.
  ///
  /// Returns the modification time of the newest .mojom found.
  _fetchFromDotMojoms(Uri base, Directory destination, File mojomsFile) async {
    DateTime newestModTime;
    Directory mojomsDir;
    var httpClient = new HttpClient();
    int repoCount = 0;
    int rootMojomCount = 0;
    int totalMojomCount = 0;
    Uri repoRoot;
    for (String line in await mojomsFile.readAsLines()) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('root:')) {
        if (_verbose) print("Found root: $line");
        if ((mojomsDir != null) && (rootMojomCount == 0)) {
          throw new FetchError("root with no mojoms: $repoRoot");
        }
        rootMojomCount = 0;
        var rootWords = line.split(" ");
        if (rootWords.length != 2) {
          throw new FetchError("Malformed root: $line");
        }
        repoRoot = Uri.parse(rootWords[1]);
        String scheme = repoRoot.scheme;
        if (!scheme.startsWith("http")) {
          // If not an absolute path. resolve relative to packageUri.
          if (!repoRoot.isAbsolute) {
            repoRoot = base.resolveUri(repoRoot);
          }
        }
        if (_verbose) print("Found repo root: $repoRoot");

        mojomsDir = new Directory(
            path.join(destination.path, 'mojm.repo.$repoCount', 'mojom'));
        await mojomsDir.create(recursive: true);
        repoCount++;
      } else {
        if (_verbose) print("Found non-root: $line");
        if (mojomsDir == null) {
          throw new FetchError('Malformed .mojoms file: $mojomsFile');
        }
        Uri uri = repoRoot.resolve(line);
        DateTime modTime = await getModificationTime(uri);
        if (_verbose) print("Fetching $uri");
        String fileString = await fetchUri(httpClient, uri);
        String filePath = path.join(mojomsDir.path, line);
        var file = new File(filePath);
        if (!await file.exists()) {
          await file.create(recursive: true);
          await file.writeAsString(fileString);
          if (_verbose) print("Wrote $filePath");
        }
        if ((newestModTime == null) || newestModTime.isBefore(modTime)) {
          newestModTime = modTime;
        }
        rootMojomCount++;
        totalMojomCount++;
      }
    }
    return [newestModTime, totalMojomCount];
  }

  _runBindingsGeneration(String script, List<String> arguments) async {
    var result;
    var stopwatch = new Stopwatch()..start();
    result = await Process.run(script, arguments);
    stopwatch.stop();
    _genMs.value += stopwatch.elapsedMilliseconds;
    return result;
  }

  /// Generate bindings for .mojom files found in [source].
  /// Bindings will be generated into [destination]/$package/... where
  /// $package is the package specified by the bindings generation process.
  /// If [packageName] is given, an exception is thrown if
  /// $package != [packageName]
  _generateForMojomDir(Directory source, Directory destination,
      {String packageName}) async {
    await for (var mojom in source.list(recursive: true)) {
      if (mojom is! File) continue;
      if (!isMojom(mojom.path)) continue;
      if (_verbose) print("Found $mojom");

      final script = path.join(
          _mojoSdk.path, 'tools', 'bindings', 'mojom_bindings_generator.py');
      final sdkInc = path.normalize(path.join(_mojoSdk.path, '..', '..'));
      final outputDir = await destination.createTemp();
      final output = outputDir.path;
      final arguments = [
        '--use_bundled_pylibs',
        '-g',
        'dart',
        '-o',
        output,
        // TODO(zra): Are other include paths needed?
        '-I',
        sdkInc,
        '-I',
        source.path,
        mojom.path
      ];

      if (_verbose || _dryRun) {
        print('Generating $mojom');
        print('$script ${arguments.join(" ")}');
      }
      if (!_dryRun) {
        final result = await _runBindingsGeneration(script, arguments);
        if (result.exitCode != 0) {
          await outputDir.delete(recursive: true);
          throw new GenerationError("$script failed:\n"
              "code: ${result.exitCode}\n"
              "stderr: ${result.stderr}\n"
              "stdout: ${result.stdout}");
        }

        // Generated .mojom.dart is under $output/dart-pkg/$PACKAGE/lib/$X
        // Move $X to |destination|/$PACKAGE/$X
        final generatedDirName = path.join(output, 'dart-pkg');
        final generatedDir = new Directory(generatedDirName);
        await for (var genpack in generatedDir.list()) {
          if (genpack is! Directory) continue;
          var libDir = new Directory(path.join(genpack.path, 'lib'));
          var name = path.relative(genpack.path, from: generatedDirName);

          if ((packageName != null) && packageName != name) {
            await outputDir.delete(recursive: true);
            throw new GenerationError(
                "Tried to generate for package $name in package $packageName");
          }

          var copyDest = new Directory(path.join(destination.path, name));
          if (_verbose) print("Copy $libDir to $copyDest");
          await _copyBindings(copyDest, libDir);
        }

        await outputDir.delete(recursive: true);
      }
    }
  }

  /// Searches for .mojom.dart files under [sourceDir] and copies them to
  /// [destDir].
  _copyBindings(Directory destDir, Directory sourceDir) async {
    await for (var mojom in sourceDir.list(recursive: true)) {
      if (mojom is! File) continue;
      if (!isMojomDart(mojom.path)) continue;
      if (_verbose) print("Found $mojom");

      final relative = path.relative(mojom.path, from: sourceDir.path);
      final dest = path.join(destDir.path, relative);
      final destDirectory = new Directory(path.dirname(dest));

      if (_errorOnDuplicate && _duplicateDetection.containsKey(dest)) {
        String original = _duplicateDetection[dest];
        throw new GenerationError(
            'Conflict: Both ${original} and ${mojom.path} supply ${dest}');
      }
      _duplicateDetection[dest] = mojom.path;

      if (_verbose || _dryRun) {
        print('Copying $mojom to $dest');
      }

      if (!_dryRun) {
        final File source = new File(mojom.path);
        final File destFile = new File(dest);
        if (await destFile.exists()) {
          await destFile.delete();
        }
        if (_verbose) print("Ensuring $destDirectory exists");
        await destDirectory.create(recursive: true);
        await source.copy(dest);
        await markFileReadOnly(dest);
      }
    }
  }
}

/// Given the location of the Mojo SDK and a root directory from which to begin
/// a search. Find .mojom files, and generates bindings for the relevant
/// packages.
class TreeGenerator {
  final MojomGenerator _generator;
  final Directory _mojoSdk;
  final Directory _mojomRootDir;
  final Directory _dartRootDir;
  final List<String> _skip;
  final bool _verbose;
  final bool _dryRun;

  Set<String> _processedPackages;

  int errors;

  TreeGenerator(
      Directory mojoSdk, this._mojomRootDir, this._dartRootDir, this._skip,
      {bool verbose: false, bool dryRun: false})
      : _mojoSdk = mojoSdk,
        _verbose = verbose,
        _dryRun = dryRun,
        _generator =
            new MojomGenerator(mojoSdk, verbose: verbose, dryRun: dryRun),
        _processedPackages = new Set<String>(),
        errors = 0;

  findAndGenerate() async {
    // Generate missing .mojoms files.
    var mojomsGenerator = new DotMojomsGenerator(
        _mojomRootDir, _dartRootDir, _skip,
        verbose: _verbose);
    List<File> generatedDotMojoms = await mojomsGenerator.generate();

    try {
      // Use those .mojoms files to generate bindings.
      await _findAndGenerateFromDotMojoms();
    } finally {
      // Delete the .mojoms files.
      for (var dotMojoms in generatedDotMojoms) {
        await dotMojoms.delete();
      }
    }
  }

  /// Find Dart packages with .mojoms files. Use them to direct bindings
  /// generation.
  _findAndGenerateFromDotMojoms() async {
    await for (var entry in _dartRootDir.list(recursive: true)) {
      if (entry is! File) continue;
      if (_shouldSkip(entry)) continue;
      if (!isDotMojoms(entry.path)) continue;
      String package = path.basename(entry.parent.path);
      if (_processedPackages.contains(package)) continue;
      _processedPackages.add(package);
      await _runGenerate(entry.parent);
    }
  }

  _runGenerate(Directory package) async {
    try {
      if (_verbose) print('Generating bindings for $package');
      await _generator.generateForPackage(package);
      if (_verbose) print('Done generating bindings for $package');
    } on GenerationError catch (e) {
      stderr.writeln('Bindings generation failed for package $package: $e');
      errors += 1;
    }
  }

  bool _shouldSkip(File f) => containsPrefix(f.path, _skip);
}

/// Given the root of a directory tree to check, and the root of a directory
/// tree containing the canonical generated bindings, checks that the files
/// match, and recommends actions to take in case they don't. The canonical
/// directory should contain a subdirectory for each package that might be
/// encountered while traversing the directory tree being checked.
class TreeChecker {
  final bool _verbose;
  final Directory _mojoSdk;
  final Directory _mojomRootDir;
  final Directory _dartRootDir;
  final Directory _canonical;
  final List<String> _skip;
  int _errors;

  TreeChecker(this._mojoSdk, this._mojomRootDir, this._dartRootDir,
      this._canonical, this._skip,
      {bool verbose: false})
      : _verbose = verbose,
        _errors = 0;

  check() async {
    // Generate missing .mojoms files if needed.
    var dotMojomsGenerator = new DotMojomsGenerator(
        _mojomRootDir, _dartRootDir, _skip,
        verbose: _verbose);
    List<File> generatedMojoms = await dotMojomsGenerator.generate();

    // Visit Dart packages with .mojoms files, checking their .mojom.dart files
    // against those under _canonical.
    Set<String> alreadySeen = new Set<String>();
    await for (var entry in _dartRootDir.list(recursive: true)) {
      if (entry is! File) continue;
      if (!isDotMojoms(entry.path)) continue;
      if (entry.path.startsWith(_canonical.path)) continue;
      String realpath = await entry.resolveSymbolicLinks();
      if (alreadySeen.contains(realpath)) continue;
      alreadySeen.add(realpath);

      if (_shouldSkip(entry)) continue;
      var parent = entry.parent;
      if (_verbose) print("Checking package at: ${parent.path}");

      await _checkAll(parent);
      await _checkSame(parent);
    }

    // If there were multiple mismatches, explain how to regenerate the bindings
    // for the whole tree.
    if (_errors > 1) {
      String dart = makeRelative(Platform.executable);
      String packRoot = (Platform.packageRoot == "")
          ? ""
          : "-p " + makeRelative(Platform.packageRoot);
      String scriptPath = makeRelative(path.fromUri(Platform.script));
      String mojoSdk = makeRelative(_mojoSdk.path);
      String root = makeRelative(_mojomRootDir.path);
      String dartRoot = makeRelative(_dartRootDir.path);
      String skips = _skip.map((s) => "-s " + makeRelative(s)).join(" ");
      stderr.writeln('It looks like there were multiple problems. '
          'You can run the following command to regenerate bindings for your '
          'whole tree:\n'
          '\t$dart $packRoot $scriptPath gen -m $mojoSdk -r $root -o $dartRoot '
          '$skips');
    }

    // Delete any .mojoms files we generated.
    for (var mojoms in generatedMojoms) {
      await mojoms.delete();
    }
  }

  int get errors => _errors;

  // Check that the files are the same.
  _checkSame(Directory package) async {
    Directory libDir = new Directory(path.join(package.path, 'lib'));
    Set<String> alreadySeen = new Set<String>();
    await for (var entry in libDir.list(recursive: true)) {
      if (entry is! File) continue;
      if (!isMojomDart(entry.path)) continue;
      String realpath = await entry.resolveSymbolicLinks();
      if (alreadySeen.contains(realpath)) continue;
      alreadySeen.add(realpath);

      String relPath = path.relative(entry.path, from: package.parent.path);
      File canonicalFile = new File(path.join(_canonical.path, relPath));
      if (!await canonicalFile.exists()) {
        if (_verbose) print("No canonical file for $entry");
        continue;
      }

      if (_verbose) print("Comparing $entry with $canonicalFile");
      int fileComparison = await compareFiles(entry, canonicalFile);
      if (fileComparison != 0) {
        String entryPath = makeRelative(entry.path);
        String canonicalPath = makeRelative(canonicalFile.path);
        if (fileComparison > 0) {
          stderr.writeln('The generated file:\n\t$entryPath\n'
              'is newer thanthe canonical file\n\t$canonicalPath\n,'
              'and they are different. Regenerate canonical files?');
        } else {
          String dart = makeRelative(Platform.executable);
          String packRoot = (Platform.packageRoot == "")
              ? ""
              : "-p " + makeRelative(Platform.packageRoot);
          String root = makeRelative(_mojomRootDir.path);
          String packagePath = makeRelative(package.path);
          String scriptPath = makeRelative(path.fromUri(Platform.script));
          String mojoSdk = makeRelative(_mojoSdk.path);
          String skips = _skip.map((s) => "-s " + makeRelative(s)).join(" ");
          stderr.writeln('For the package: $packagePath\n'
              'The generated file:\n\t$entryPath\n'
              'is older than the canonical file:\n\t$canonicalPath\n'
              'and they are different. Regenerate by running:\n'
              '\t$dart $packRoot $scriptPath single -m $mojoSdk -r $root '
              '-p $packagePath $skips');
        }
        _errors++;
        return;
      }
    }
  }

  // Check that every .mojom.dart in the canonical package is also in the
  // package we are checking.
  _checkAll(Directory package) async {
    String packageName = path.relative(package.path, from: package.parent.path);
    String canonicalPackagePath =
        path.join(_canonical.path, packageName, 'lib');
    Directory canonicalPackage = new Directory(canonicalPackagePath);
    if (!await canonicalPackage.exists()) return;

    Set<String> alreadySeen = new Set<String>();
    await for (var entry in canonicalPackage.list(recursive: true)) {
      if (entry is! File) continue;
      if (!isMojomDart(entry.path)) continue;
      String realpath = await entry.resolveSymbolicLinks();
      if (alreadySeen.contains(realpath)) continue;
      alreadySeen.add(realpath);

      String relPath = path.relative(entry.path, from: canonicalPackage.path);
      File genFile = new File(path.join(package.path, 'lib', relPath));
      if (_verbose) print("Checking that $genFile exists");
      if (!await genFile.exists()) {
        String dart = makeRelative(Platform.executable);
        String packRoot = (Platform.packageRoot == "")
            ? ""
            : "-p " + makeRelative(Platform.packageRoot);
        String root = makeRelative(_mojomRootDir.path);
        String genFilePath = makeRelative(genFile.path);
        String packagePath = makeRelative(package.path);
        String scriptPath = makeRelative(path.fromUri(Platform.script));
        String mojoSdk = makeRelative(_mojoSdk.path);
        String skips = _skip.map((s) => "-s " + makeRelative(s)).join(" ");
        stderr.writeln('The generated file:\n\t$genFilePath\n'
            'is needed but does not exist. Run the command\n'
            '\t$dart $packRoot $scriptPath single -m $mojoSdk -r $root '
            '-p $packagePath $skips');
        _errors++;
        return;
      }
    }
  }

  bool _shouldSkip(File f) => containsPrefix(f.path, _skip);
}
